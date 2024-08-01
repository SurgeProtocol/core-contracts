// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {Math} from "openzeppelin/utils/math/Math.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";
import {IERC6551Registry} from "erc6551/interfaces/IERC6551Registry.sol";
import {AccountV3TBD} from "./AccountV3TBD.sol";
import {IDealNFT} from "./interfaces/IDealNFT.sol";
import {IWhitelist} from "./interfaces/IWhitelist.sol";
import {UD60x18, ud, ln, intoUint256} from "prb/UD60x18.sol";

/**
 * @title DealNFT
 * @notice Contract for managing NFT-based deals
 */
contract DealNFT is ERC721, IDealNFT, ReentrancyGuard {
    using Math for uint256;
    using Strings for address;
    using Strings for uint256;
    using SafeERC20 for IERC20Metadata;

    // Events
    event Deal(address indexed sponsor, string name, string symbol);
    event Setup(address sponsor, address escrowToken, uint256 closingDelay, uint256 unstakingFee, string web, string twitter, string image);
    event Activate(address indexed sponsor);
    event Configure(address indexed sponsor, string description, uint256 closingTime, uint256 dealMinimum, uint256 dealMaximum, address arbitrator);
    event Transferable(address indexed sponsor, bool transferable);
    event ClaimApproved(address indexed sponsor, address arbitrator);
    event SetStakersWhitelist(address whitelist);
    event SetClaimsWhitelist(address whitelist);
    event Cancel(address indexed sponsor);
    event Claim(address indexed sponsor, address indexed staker, uint256 tokenId, uint256 amount);
    event Stake(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);
    event Unstake(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);
    event Recover(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);
    event WebsiteUpdated(string website);
    event TwitterUpdated(string twitter);
    event DescriptionUpdated(string description);
    event ClosingTimeUpdated(uint256 indexed closingTime);
    event DealRangeUpdated(uint256 indexed dealMinimum, uint256 indexed dealMaximum);
    event ArbitratorUpdated(address indexed arbitrator);

    // Enum for deal states
    enum State { Setup, Active, Claiming, Closed, Canceled }

    uint256 public constant CLAIMING_PERIOD = 1 weeks;
    uint256 public constant CLAIMING_FEE = 3e4; // 3%
    uint256 private constant MAX_CLOSING_RANGE = 52 weeks;
    uint256 private constant MAX_FEE = 1e5;
    uint256 private constant PRECISION = 1e6;
    address private constant ADDRESS_ZERO = address(0);

    // Private state variables
    uint256 private _tokenId;
    uint256 private _claimId;
    bool private _canceled;
    bool private _active;

    // Constructor parameters
    IERC6551Registry private immutable _registry;
    address private immutable _implementation;
    string private _base;
    address public immutable sponsor;
    address public immutable treasury;

    // Setup parameters
    IERC20Metadata public escrowToken;
    IERC20Metadata public rewardToken;
    uint256 public closingDelay;
    uint256 public unstakingFee;
    string public website;
    string public twitter;
    string public image;

    // Configuration parameters
    string public description;
    uint256 public closingTime;
    uint256 public dealMinimum;
    uint256 public dealMaximum;
    address public arbitrator;
    uint256 public multiplier;
    uint256 public distributionAmount;

    bool public transferable;
    bool public claimApproved;

    // Deal statistics
    uint256 public totalClaimed;
    mapping(uint256 tokenId => uint256) public stakedAmount;
    mapping(uint256 tokenId => uint256) public claimedAmount;
    mapping(address staker => uint256) public stakes;

    // Whitelists
    IWhitelist public stakersWhitelist;
    IWhitelist public claimsWhitelist;

    struct StakeData {
        address owner;
        address tba;
        uint256 staked;
        uint256 claimed;
    }

    /**
     * @notice Constructor to initialize DealNFT contract
     * @param registry_ The address of the registry contract
     * @param implementation_ The address of the implementation contract
     * @param sponsor_ The address of the sponsor of the deal
     * @param treasury_ The address of the treasury of the deal
     * @param name_ The name of the NFT
     * @param symbol_ The symbol of the NFT
     * @param baseURI_ The base URI for the NFTs
     */
    constructor(
        address registry_,
        address implementation_,
        address sponsor_,
        address treasury_,
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) ERC721(name_, symbol_) {
        require(registry_ != ADDRESS_ZERO, "registry cannot be zero");
        require(implementation_ != ADDRESS_ZERO, "implementation cannot be zero");
        require(sponsor_ != ADDRESS_ZERO, "sponsor cannot be zero");
        require(treasury_ != ADDRESS_ZERO, "treasury cannot be zero");
        require(bytes(name_).length > 0, "name cannot be empty");
        require(bytes(symbol_).length > 0, "symbol cannot be empty");
        require(bytes(baseURI_).length > 0, "baseURI cannot be empty");

        _registry = IERC6551Registry(registry_);
        _implementation = implementation_;

        sponsor = sponsor_;
        treasury = treasury_;

        _base = string.concat(baseURI_, "/chain/", block.chainid.toString(), "/deal/", address(this).toHexString(), "/token/");

        emit Deal(sponsor, name_, symbol_);
    }


    /**
     * @notice modifier to check claim requirements
     */
    modifier canClaim() {
        require(arbitrator == ADDRESS_ZERO || claimApproved, "claim not approved");
        require(_claimId < _tokenId, "token id out of bounds");
        require(state() == State.Claiming, "not in closing week");
        require(_totalStaked(_tokenId) >= dealMinimum, "minimum stake not reached");
        _;
    }

    /**
     * @notice Modifier to check the deal can be configured
     */
    modifier canConfigure() {
        require(state() < State.Closed, "cannot configure anymore");

        if(state() == State.Claiming) {
            require(_totalStaked(_tokenId) < dealMinimum, "minimum stake reached");
        }

        _;
    }

    /**
     * @notice Modifier to check the closing time is valid
     * @param closingTime_ The closing time to check
     */
    modifier validClosingTime(uint256 closingTime_) {
        require(closingTime_ == 0 || closingTime_ >= block.timestamp + closingDelay, "invalid closing time");
        require(closingTime_ <= block.timestamp + MAX_CLOSING_RANGE, "invalid closing time");
        _;
    }

    /**
     * @notice Modifier to check the caller is the sponsor
     */
    modifier onlySponsor() {
        require(msg.sender == sponsor, "not the sponsor");
        _;
    }

    /**
     * @notice Modifier to check the caller is the arbitrator
     */
    modifier onlyArbitrator() {
        require(msg.sender == arbitrator, "not the arbitrator");
        _;
    }

    /**
     * @notice Modifier to check the caller is the owner of the NFT
     * @param tokenId The ID of the NFT
     */
    modifier onlyTokenOwner(uint256 tokenId) {
        require(msg.sender == ownerOf(tokenId), "not the nft owner");
        _;
    }

    /**
     * @notice Modifier to check the caller is the sponsor or arbitrator
     */
    modifier onlySponsorOrArbitrator() {
        require(msg.sender == sponsor || msg.sender == arbitrator, "not the sponsor or arbitrator");
        _;
    }

    /**
     * @notice Setup the deal
     * @param escrowToken_ The address of the escrow token
     * @param closingDelay_ The delay before closing the deal
     * @param unstakingFee_ The fee for unstaking tokens
     * @param website_ The website associated with the deal
     * @param twitter_ The Twitter account associated with the deal
     * @param image_ The image associated with the deal
     */
    function setup(
        address escrowToken_,
        uint256 closingDelay_,
        uint256 unstakingFee_,
        string memory website_,
        string memory twitter_,
        string memory image_
    ) external nonReentrant onlySponsor {
        require(state() == State.Setup, "cannot setup anymore");

        escrowToken = IERC20Metadata(escrowToken_);
        closingDelay = closingDelay_;
        unstakingFee = unstakingFee_;
        website = website_;
        twitter = twitter_;
        image = image_;

        emit Setup(sponsor, address(escrowToken), closingDelay, unstakingFee, website, twitter, image);
    }

    /**
     * @notice Set the sponsor's website
     * @param website_ The website URL
     */
    function setWeb(string memory website_) external nonReentrant onlySponsor canConfigure {
        website = website_;
        emit WebsiteUpdated(website_);
    }

    /**
     * @notice Set the sponsor's Twitter handle
     * @param twitter_ The Twitter handle
     */
    function setTwitter(string memory twitter_) external nonReentrant onlySponsor canConfigure {
        twitter = twitter_;
        emit TwitterUpdated(twitter_);
    }

    /**
     * @notice Activates the deal
     * @dev requires all setup parameters to be set
     */
    function activate() external nonReentrant onlySponsor {
        require(address(escrowToken) != ADDRESS_ZERO, "sponsor cannot be zero");
        require(closingDelay > 0, "closing delay cannot be zero");
        require(closingDelay < MAX_CLOSING_RANGE, "closing delay too big");
        require(unstakingFee <= MAX_FEE, "cannot be bigger than 10%");
        require(bytes(website).length > 0, "web cannot be empty");
        require(bytes(twitter).length > 0, "twitter cannot be empty");
        require(bytes(image).length > 0, "image cannot be empty");

        _active = true;

        emit Activate(sponsor);
    }

    /**
     * @notice Configure the deal
     * @param description_ Description of the deal
     * @param closingTime_ Closing time of the deal
     * @param dealMinimum_ Minimum amount of tokens required for the deal
     * @param dealMaximum_ Maximum amount of tokens allowed for the deal
     */
    function configure(
        string memory description_,
        uint256 closingTime_,
        uint256 dealMinimum_,
        uint256 dealMaximum_,
        address arbitrator_
    ) external nonReentrant onlySponsor canConfigure validClosingTime(closingTime_) {
        require(dealMinimum_ <= dealMaximum_, "wrong deal range");

        description = description_;
        closingTime = closingTime_;
        dealMinimum = dealMinimum_;
        dealMaximum = dealMaximum_;
        arbitrator = arbitrator_;

        emit Configure(sponsor, description, closingTime, dealMinimum, dealMaximum, arbitrator);
    }

    /**
     * @notice Set the description of the deal
     * @param description_ The description of the deal
     */
    function setDescription(string memory description_) external nonReentrant onlySponsor canConfigure {
        description = description_;
        emit DescriptionUpdated(description_);
    }

    /**
     * @notice Set the closing time of the deal
     * @param closingTime_ The closing time of the deal
     */
    function setClosingTime(uint256 closingTime_) external 
        nonReentrant onlySponsor canConfigure validClosingTime(closingTime_)
    {
        closingTime = closingTime_;
        emit ClosingTimeUpdated(closingTime_);
    }

    /**
     * @notice Set the deal boundaries
     * @param dealMinimum_ The minimum amount of tokens required for the deal
     * @param dealMaximum_ The maximum amount of tokens allowed for the deal
     */
    function setDealRange(uint256 dealMinimum_, uint256 dealMaximum_) external nonReentrant onlySponsor canConfigure {
        require(dealMinimum_ <= dealMaximum_, "wrong deal range");
        dealMinimum = dealMinimum_;
        dealMaximum = dealMaximum_;
        emit DealRangeUpdated(dealMinimum_, dealMaximum_);
    }

    /**
     * @notice Set the arbitrator of the deal
     * @param arbitrator_ The address of the arbitrator
     */
    function setArbitrator(address arbitrator_) external nonReentrant onlySponsor canConfigure {
        arbitrator = arbitrator_;
        emit ArbitratorUpdated(arbitrator_);
    }

    /**
     * @notice Set the multiplier of the reward tokens
     * @param multiplier_ The multiplier of the reward tokens
     * @dev multiplier is in 1e6 precision
     */
    function setMultiplier(uint256 multiplier_) external nonReentrant onlySponsor canConfigure {
        multiplier = multiplier_;
    }

    /**
     * @notice Transfer rewards to the deal
     * @param amount The amount of tokens to transfer
     */
    function transferRewards(uint256 amount) external nonReentrant onlySponsor {
        require(address(rewardToken) != ADDRESS_ZERO, "reward token not set");
        rewardToken.safeTransferFrom(sponsor, address(this), amount);
        distributionAmount += amount;
    }

    /**
     * @notice Recover rewards from the deal
     */
    function recoverRewards() external nonReentrant onlySponsor {
        require(state() == State.Closed || state() == State.Canceled, "cannot recover rewards");
        rewardToken.safeTransfer(sponsor, rewardToken.balanceOf(address(this)));
    }

    /**
     * @notice Set the reward token
     * @param rewardToken_ The address of the reward token
     */
    function setRewardToken(address rewardToken_) external nonReentrant onlySponsor {
        rewardToken = IERC20Metadata(rewardToken_);
    }

    /**
     * @notice Set whether the NFTs are transferable or not
     * @param transferable_ Boolean indicating if NFTs are transferable
     */
    function setTransferable(bool transferable_) external nonReentrant onlySponsor {
        require(state() != State.Canceled, "cannot be changed anymore");
        require(!_afterClosed(), "cannot be changed anymore");

        transferable = transferable_;
        emit Transferable(sponsor, transferable_);
    }

    /**
     * @notice Approve the claim of the deal
     */
    function approveClaim() external nonReentrant onlyArbitrator {
        claimApproved = true;
        emit ClaimApproved(sponsor, arbitrator);
    }

    /**
     * @notice configure whitelists for staking
     * @param whitelist_ enable whitelisting on stakes
     */
    function setStakersWhitelist(address whitelist_) external nonReentrant onlySponsor {
        stakersWhitelist = IWhitelist(whitelist_);
        emit SetStakersWhitelist(whitelist_);
    }

    /**
     * @notice configure whitelists for claming
     * @param whitelist_ enable whitelisting on claim
     */
    function setClaimsWhitelist(address whitelist_) external nonReentrant onlySponsor {
        claimsWhitelist = IWhitelist(whitelist_);
        emit SetClaimsWhitelist(whitelist_);
    }

    /**
     * @notice Cancel the deal
     */
    function cancel() external nonReentrant onlySponsorOrArbitrator {
        require(state() <= State.Active, "cannot be canceled");
        _canceled = true;
        emit Cancel(sponsor);
    }

    /**
     * @notice Stake tokens into the deal
     * @param amount The amount of tokens to stake
     */
    function stake(uint256 amount) external nonReentrant {
        require(state() == State.Active, "not an active deal");
        require(amount > 0, "invalid amount");
        uint256 currentStake = stakes[msg.sender] + amount;

        if(address(stakersWhitelist) != ADDRESS_ZERO){
            require(stakersWhitelist.canStake(msg.sender, currentStake), "whitelist error");
        }

        uint256 newTokenId = _tokenId++;
        stakedAmount[newTokenId] = amount;
        stakes[msg.sender] = currentStake;

        _safeMint(msg.sender, newTokenId);
        address newAccount = _createTokenBoundAccount(newTokenId);
        escrowToken.safeTransferFrom(msg.sender, newAccount, amount);

        emit Stake(msg.sender, newAccount, newTokenId, amount);
    }

    /**
     * @notice Unstake tokens from the deal
     * @param tokenId The ID of the token to unstake
     */
    function unstake(uint256 tokenId) external nonReentrant onlyTokenOwner(tokenId) { 
        require(state() <= State.Active, "cannot unstake after claiming/closed/canceled");

        uint256 amount = stakedAmount[tokenId];
        AccountV3TBD tokenBoundAccount = getTokenBoundAccount(tokenId);

        stakedAmount[tokenId] = 0;
        stakes[msg.sender] -= amount;

        uint256 fee = amount.mulDiv(unstakingFee, PRECISION);
        tokenBoundAccount.send(msg.sender, amount - fee);
        tokenBoundAccount.send(sponsor, fee.ceilDiv(2));
        tokenBoundAccount.send(treasury, fee/2);

        emit Unstake(msg.sender, address(tokenBoundAccount), tokenId, amount);
    }

    /**
     * @notice Recover tokens from the deal if the deal is canceled or closed
     * @param tokenId The ID of the token to recover
     */
    function recover(uint256 tokenId) external nonReentrant onlyTokenOwner(tokenId) { 
        require(state() >= State.Closed, "cannot recover before closed/canceled");

        AccountV3TBD tokenBoundAccount = getTokenBoundAccount(tokenId);
        uint256 balance = escrowToken.balanceOf(address(tokenBoundAccount));

        tokenBoundAccount.send(msg.sender, balance);

        emit Recover(msg.sender, address(tokenBoundAccount), tokenId, balance);
    }

    /**
     * @notice Claim tokens from the deal
     */
    function claim() external nonReentrant onlySponsor canClaim {
        require(distributionAmount > 0, "no rewards to claim");
        uint maximum = Math.min(dealMaximum, _totalStaked(_tokenId));
        while(_claimId < _tokenId) {
            _claimNext(maximum);
        }
    }

    /**
     * @notice Claim the next token id from the deal
     */
    function claimNext() external nonReentrant onlySponsor canClaim {
        require(distributionAmount > 0, "no rewards to claim");
         uint maximum = Math.min(dealMaximum, _totalStaked(_tokenId));
        _claimNext(maximum);
    }

    /**
     * @notice Internal function to claim the next token id from the deal
     * @dev funds are sent from the TBA to the sponsor until dealMaximum.
     */
    function _claimNext(uint256 maximum) private {
        uint256 tokenId = _claimId++;
        uint256 amount = stakedAmount[tokenId];
        address staker = ownerOf(tokenId);

        if(address(claimsWhitelist) != ADDRESS_ZERO && !claimsWhitelist.canClaim(staker)) {
            return;
        }

        if(totalClaimed + amount > dealMaximum){
            amount = dealMaximum - totalClaimed;
        }

        if(amount > 0) {        
            claimedAmount[tokenId] = amount;
            totalClaimed += amount;
            uint256 bonus = getRewardsOf(tokenId, maximum);
            if(bonus > 0) rewardToken.safeTransfer(staker, bonus);
            
            AccountV3TBD tokenBoundAccount = getTokenBoundAccount(tokenId);
            uint256 fee = amount.mulDiv(CLAIMING_FEE, PRECISION);

            tokenBoundAccount.send(sponsor, amount - fee);
            tokenBoundAccount.send(treasury, fee);

            emit Claim(sponsor, staker, tokenId, amount);
        }
    }

    /**
     * @notice Get current state of the deal
     * @dev a deal is considered closed if the tokens have been claimed by the sponsor
     */
    function state() public view returns (State) {
        if(_canceled) return State.Canceled;

        if(_beforeClose()) {
            if(_active) return State.Active;
            return State.Setup;
        }

        if(_afterClosed()) return State.Closed;

        if(_isClaimed()) return State.Closed;

        return State.Claiming;
    }

    /** 
     * @notice Get the total amount of tokens staked in the deal
     */
    function totalStaked() external view returns (uint256) {
        return _totalStaked(_tokenId);
    }

    /**
     * @notice Get the stakes from 0 to a NFT id
     * @param index The index of the last NFT
     */
    function getStakesTo(uint256 index) public view returns (StakeData[] memory) {
        if(index >= _tokenId) index = _tokenId > 0 ? _tokenId - 1 : 0;
        StakeData[] memory stakesTo = new StakeData[](index + 1);

        for(uint256 i = 0; i <= index; ) {
            address staker = ownerOf(i);
            stakesTo[i] = StakeData(staker, address(getTokenBoundAccount(i)), stakedAmount[i], claimedAmount[i]);
            unchecked { i++; }
        }

        return stakesTo;
    }

    /**
     * @notice Get the bonus for a particular stake
     * @param tokenId The index of the stake
     * @dev bonus is in 1eN precision, where N is the decimals of the reward token
     * @dev T = total amount to be distributed
     * @dev M = first bonus discount
     * @dev C = deal maximum
     * @dev L = last stake
     * @dev X = sum of previous stakes
     * @dev R = rewards
     * @dev K1, K2, constants
     */
    function getRewardsOf(uint256 tokenId, uint256 maximum) public view returns(uint256) {
        if (tokenId >= _tokenId) return 0;

        uint256 L = stakedAmount[tokenId];
        uint256 T = distributionAmount;
        uint256 M = multiplier;
        uint256 C = maximum;

        if(T == 0 || L == 0 || M == 0) return 0;
        
        uint256 S = _totalStaked(tokenId);
        uint256 X = S - L;

        if (S > C) { // dealMaximum was reached - calculate bonus for a partial stake
            L = C > X ? C - X : 0;
        }

        uint256 lnM = intoUint256(ln(ud(M)));
        uint256 k1 = (T * 1e18) / lnM; // ends up with reward decimals
        uint256 k2 = C * 1e18 / (M - 1e18); // ends up with escrow decimals
        uint256 k3 = 1e18 + (L * 1e18 / (X + k2)); // ends up with precision 1e18

        uint256 result = k1 * intoUint256(ln(ud(k3))) / 1e18; // result has reward token decimals
        return result;
    }

    /**
     * @notice Get next available token id
     */
    function nextId() public view returns (uint256) {
        return _tokenId;
    }

    /**
     * @notice Get the TBA of a particular NFT
     */
    function getTokenBoundAccount(uint256 tokenId) public view returns(AccountV3TBD) {
        return AccountV3TBD(payable(_registry.account(_implementation, bytes32(abi.encode(0)), block.chainid, address(this), tokenId)));
    }

    /**
     * @notice Create an account bound to the NFT
     */
    function _createTokenBoundAccount(uint256 tokenId) private returns(address) {
        bytes32 salt = bytes32(abi.encode(0));
        address payable walletAddress = payable(_registry.createAccount(_implementation, salt, block.chainid, address(this), tokenId));
        AccountV3TBD newAccount = AccountV3TBD(walletAddress);
        require(newAccount.owner() == msg.sender, "owner mismatch");

        return walletAddress;
    }

    /**
     * @notice Block escrow token from being interacted with from the TBA
     */
    function allowToken(address to) external view returns (bool) {
        return to != address(escrowToken);
    }

    /**
     * @notice Check if all tokens have been claimed by the sponsor
     */
    function _isClaimed() private view returns (bool) {
        return totalClaimed > 0 && (totalClaimed >= dealMaximum || totalClaimed >= _totalStaked(_tokenId));
    }

    /**
     * @notice Check if the current time is before closing time
     */
    function _beforeClose() private view returns (bool) {
        return closingTime == 0 || block.timestamp <= closingTime;
    }

    /**
     * @notice Check if the current time is after closing time
     */
    function _afterClosed() private view returns (bool) {
        return closingTime > 0 && block.timestamp > (closingTime + CLAIMING_PERIOD);
    }

    /**
     * @inheritdoc ERC721
     */
    function _transfer(address from, address to, uint256 tokenId) internal override {
        require(transferable, "not transferable");

        uint256 amount = stakedAmount[tokenId];        

        if(address(stakersWhitelist) != ADDRESS_ZERO){
            uint256 staked = stakes[to] + amount;
            require(stakersWhitelist.canStake(to, staked), "whitelist error");
        }

        stakes[from] -= amount;
        stakes[to] += amount;

        super._transfer(from, to, tokenId);
    }

    /**
     * @inheritdoc ERC721
     */
    function _baseURI() internal view override returns (string memory) {
        return _base;
    }

    /**
     * @notice Get the total amount of tokens staked in the deal
     */
    function _totalStaked(uint256 limit) internal view returns (uint256 total) {
        if(_tokenId == 0) return 0;
        if(limit >= _tokenId) limit = _tokenId - 1;

        for(uint256 i = 0; i <= limit; i++) {
            address staker = ownerOf(i);
            if(address(claimsWhitelist) == ADDRESS_ZERO || claimsWhitelist.canClaim(staker)) {
                total += stakedAmount[i];
            }
        }
    }
}
