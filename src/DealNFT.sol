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
 * @dev Error codes:
 * SRG001: registry is zero
 * SRG002: implementation is zero
 * SRG003: sponsor is zero
 * SRG004: treasury is zero
 * SRG005: name is empty
 * SRG006: symbol is empty
 * SRG007: baseURI is empty
 * SRG008: closing delay is zero
 * SRG009: closing delay is too big
 * SRG010: closing delay is bigger than 10%
 * SRG011: website is empty
 * SRG012: social is empty
 * SRG013: image is empty
 * SRG014: delivery token is zero
 * SRG015: invalid amount
 * SRG016: invalid closing time
 *
 * SRG020: only sponsor
 * SRG021: only arbitrator
 * SRG022: only token owner
 * SRG023: only sponsor or arbitrator
 * SRG024: owner mismatch
 *
 * SRG030: cannot setup
 * SRG031: wrong deal range
 * SRG032: multiple must be greater than or equal to 1
 * SRG033: cannot recover delivery tokens
 * SRG034: cannot be changed
 * SRG035: cannot be canceled
 * SRG036: not an active deal
 * SRG037: whitelist error
 * SRG038: cannot unstake after claiming/closed/canceled
 * SRG039: cannot recover before closed/canceled
 * SRG040: not transferable
 * SRG041: whitelist error
 * SRG042: claim not approved
 * SRG043: token id out of bounds
 * SRG044: not in closing week
 * SRG045: minimum stake not reached
 * SRG046: minimum stake reached
 * SRG047: cannot configure
 */
contract DealNFT is ERC721, IDealNFT, ReentrancyGuard {
    using Math for uint256;
    using Strings for address;
    using Strings for uint256;
    using SafeERC20 for IERC20Metadata;

    // Events
    event Setup(address escrowToken, uint256 closingDelay, uint256 unstakingFee, string web, string social, string image, string description, State state);
    event Configure(string description, string social, string website, uint256 closingTime, uint256 dealMinimum, uint256 dealMaximum, address arbitrator, State state);
    event Transferable(bool transferable);
    event SetStakersWhitelist(address whitelist);
    event SetClaimsWhitelist(address whitelist);
    event Claim(address indexed staker, uint256 tokenId, uint256 amount);
    event Stake(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);
    event Unstake(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);
    event Recover(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);
    event DescriptionUpdated(string description);
    event ClosingTimeUpdated(uint256 indexed closingTime);
    event DealRangeUpdated(uint256 indexed dealMinimum, uint256 indexed dealMaximum);
    event ArbitratorUpdated(address indexed arbitrator);
    event StateUpdated(State state);

    // Enum for deal states
    enum State { Setup, Active, Claiming, Closed, Canceled }

    uint256 private constant MAX_FEE = 1e5;
    uint256 private constant PRECISION = 1e6;
    address private constant ADDRESS_ZERO = address(0);

    bool private _canceled;
    bool private _active;
    bool public transferable;
    bool public claimApproved;

    address public immutable sponsor;
    address public immutable treasury;
    IERC6551Registry private immutable _registry;
    address private immutable _implementation;
    address public arbitrator;

    uint256 private _tokenId;
    uint256 private _claimId;
    uint256 public closingDelay;
    uint256 public unstakingFee;
    uint256 public closingTime;
    uint256 public dealMinimum;
    uint256 public dealMaximum;
    uint256 public multiple;
    uint256 public deliveryAmount;
    uint256 public totalClaimed;
    uint256 public chainMaximum;

    IERC20Metadata public escrowToken;
    IERC20Metadata public deliveryToken;
    IWhitelist public stakersWhitelist;
    IWhitelist public claimsWhitelist;

    string private _base;
    string public website;
    string public social;
    string public image;
    string public description;

    uint256 public constant CLAIMING_PERIOD = 1 weeks;
    uint256 public constant CLAIMING_FEE = 3e4; // 3%
    uint256 private constant MAX_CLOSING_RANGE = 52 weeks;

    mapping(uint256 tokenId => uint256) public stakedAmount;
    mapping(uint256 tokenId => uint256) public claimedAmount;
    mapping(address staker => uint256) public stakes;

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
        require(registry_ != ADDRESS_ZERO, "SRG001");
        require(implementation_ != ADDRESS_ZERO, "SRG002");
        require(sponsor_ != ADDRESS_ZERO, "SRG003");
        require(treasury_ != ADDRESS_ZERO, "SRG004");
        require(bytes(name_).length > 0, "SRG005");
        require(bytes(symbol_).length > 0, "SRG006");
        require(bytes(baseURI_).length > 0, "SRG007");

        _registry = IERC6551Registry(registry_);
        _implementation = implementation_;
        sponsor = sponsor_;
        treasury = treasury_;
        multiple = 1e18;
        _base = string.concat(baseURI_, "/chain/", block.chainid.toString(), "/deal/", address(this).toHexString(), "/token/");
    }

    /**
     * @notice Modifier to check the caller is the sponsor
     */
    modifier onlySponsor() {
        require(msg.sender == sponsor, "SRG020");
        _;
    }

    /**
     * @notice Modifier to check the caller is the arbitrator
     */
    modifier onlyArbitrator() {
        require(msg.sender == arbitrator, "SRG021");
        _;
    }

    /**
     * @notice Modifier to check the caller is the owner of the NFT
     * @param tokenId The ID of the NFT
     */
    modifier onlyTokenOwner(uint256 tokenId) {
        require(msg.sender == ownerOf(tokenId), "SRG022");
        _;
    }

    /**
     * @notice Modifier to check the caller is the sponsor or arbitrator
     */
    modifier onlySponsorOrArbitrator() {
        require(msg.sender == sponsor || msg.sender == arbitrator, "SRG023");
        _;
    }

    /**
     * @notice Setup the deal
     * @param escrowToken_ The address of the escrow token
     * @param closingDelay_ The delay before closing the deal
     * @param unstakingFee_ The fee for unstaking tokens
     * @param website_ The website associated with the deal
     * @param social_ The Social account associated with the deal
     * @param image_ The image associated with the deal
     * @param description_ The description of the deal
     */
    function setup(
        address escrowToken_,
        uint256 closingDelay_,
        uint256 unstakingFee_,
        string memory social_,
        string memory website_,
        string memory image_,
        string memory description_
    ) external onlySponsor {
        require(state() == State.Setup, "SRG030");

        escrowToken = IERC20Metadata(escrowToken_);
        closingDelay = closingDelay_;
        unstakingFee = unstakingFee_;
        social = social_;
        website = website_;
        image = image_;
        description = description_;

        emit Setup(address(escrowToken), closingDelay, unstakingFee, website, social, image, description, State.Setup);
    }

    /**
     * @notice Activates the deal
     * @dev requires all setup parameters to be set
     */
    function activate() external onlySponsor {
        require(address(escrowToken) != ADDRESS_ZERO, "SRG003");
        require(closingDelay > 0, "SRG008");
        require(closingDelay < MAX_CLOSING_RANGE, "SRG009");
        require(unstakingFee <= MAX_FEE, "SRG010");
        require(bytes(website).length > 0, "SRG011");
        require(bytes(social).length > 0, "SRG012");
        require(bytes(image).length > 0, "SRG013");

        _active = true;

        emit StateUpdated(State.Active);
    }

    /**
     * @notice Configure the deal
     * @param description_ Description of the deal
     * @param social_ Social account associated with the deal
     * @param website_ Website associated with the deal
     * @param closingTime_ Closing time of the deal
     * @param dealMinimum_ Minimum amount of tokens required for the deal
     * @param dealMaximum_ Maximum amount of tokens allowed for the deal
     * @param arbitrator_ Address of the arbitrator
    */
    function configure(
        string memory description_,
        string memory social_,
        string memory website_,
        uint256 closingTime_,
        uint256 dealMinimum_,
        uint256 dealMaximum_,
        address arbitrator_
    ) external onlySponsor {
        _canConfigure();
        _validClosingTime(closingTime_);
        require(dealMinimum_ <= dealMaximum_, "SRG031");

        description = description_;
        social = social_;
        website = website_;
        closingTime = closingTime_;
        dealMinimum = dealMinimum_;
        dealMaximum = dealMaximum_;
        arbitrator = arbitrator_;

        emit Configure(description, social, website, closingTime, dealMinimum, dealMaximum, arbitrator, State.Active);
    }

    /**
     * @notice Set the multiple of the delivery tokens
     * @param multiple_ The multiple of the delivery tokens
     * @dev multiple is in 1e6 precision
     */
    function setMultiple(uint256 multiple_) external onlySponsor {
        _canConfigure();
        require(multiple_ >= 1e18, "SRG032");
        multiple = multiple_;
    }

    /**
     * @notice Deposit delivery tokens to the deal
     * @param amount The amount of tokens to transfer
     */
    function depositDeliveryTokens(uint256 amount) external nonReentrant onlySponsor {
        require(address(deliveryToken) != ADDRESS_ZERO, "SRG014");
        deliveryToken.safeTransferFrom(sponsor, address(this), amount);
        deliveryAmount += amount;
    }

    /**
     * @notice Recover delivery tokens from the deal
     */
    function recoverDeliveryTokens() external nonReentrant onlySponsor {
        require(state() == State.Closed || state() == State.Canceled, "SRG033");
        deliveryToken.safeTransfer(sponsor, deliveryToken.balanceOf(address(this)));
    }

    /**
     * @notice Set the delivery token
     * @param deliveryToken_ The address of the delivery token
     */
    function setDeliveryToken(address deliveryToken_) external onlySponsor {
        require(address(deliveryToken_) != ADDRESS_ZERO, "SRG014");
        deliveryToken = IERC20Metadata(deliveryToken_);
    }

    /**
     * @notice Set whether the NFTs are transferable or not
     * @param transferable_ Boolean indicating if NFTs are transferable
     */
    function setTransferable(bool transferable_) external onlySponsor {
        require(state() != State.Canceled, "SRG034");
        require(!_afterClosed(), "SRG034");

        transferable = transferable_;
        emit Transferable(transferable_);
    }

    /**
     * @notice Approve the claim of the deal
     */
    function approveClaim() external onlyArbitrator {
        claimApproved = true;
    }

    /**
     * @notice Set the maximum amount of tokens allowed for the deal
     */
    function setChainMaximum(uint256 maximum) external onlyArbitrator {
        chainMaximum = maximum;
    }

    /**
     * @notice configure whitelists for staking
     * @param whitelist_ enable whitelisting on stakes
     */
    function setStakersWhitelist(address whitelist_) external onlySponsor {
        stakersWhitelist = IWhitelist(whitelist_);
        emit SetStakersWhitelist(whitelist_);
    }

    /**
     * @notice configure whitelists for claming
     * @param whitelist_ enable whitelisting on claim
     */
    function setClaimsWhitelist(address whitelist_) external onlySponsor {
        claimsWhitelist = IWhitelist(whitelist_);
        emit SetClaimsWhitelist(whitelist_);
    }

    /**
     * @notice Cancel the deal
     */
    function cancel() external onlySponsorOrArbitrator {
        require(state() <= State.Active, "SRG035");
        _canceled = true;
        emit StateUpdated(State.Canceled);
    }

    /**
     * @notice Stake tokens into the deal
     * @param staker The address of the staker
     * @param amount The amount of tokens to stake
     */
    function stake(address staker, uint256 amount) external nonReentrant {
        _stake(staker, amount);
    }

    /**
     * @notice Stake tokens into the deal
     * @param amount The amount of tokens to stake
     */
    function stake(uint256 amount) external nonReentrant {
        _stake(msg.sender, amount);
    }

    /**
     * @notice Unstake tokens from the deal
     * @param tokenId The ID of the token to unstake
     */
    function unstake(uint256 tokenId) external nonReentrant onlyTokenOwner(tokenId) { 
        require(state() <= State.Active, "SRG038");

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
        require(state() >= State.Closed, "SRG039");

        AccountV3TBD tokenBoundAccount = getTokenBoundAccount(tokenId);
        uint256 balance = escrowToken.balanceOf(address(tokenBoundAccount));

        tokenBoundAccount.send(msg.sender, balance);

        emit Recover(msg.sender, address(tokenBoundAccount), tokenId, balance);
    }

    /**
     * @notice Claim tokens from the deal
     */
    function claim() external nonReentrant onlySponsor {
        _canClaim();
        uint maximum = Math.min(dealMaximum, _totalStaked(_tokenId));
        while(_claimId < _tokenId) {
            _claimNext(maximum);
        }
        emit StateUpdated(State.Closed);
    }

    /**
     * @notice Claim the next token id from the deal
     */
    function claimNext() external nonReentrant onlySponsor {
        _canClaim();
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

        uint256 chainMaximum_ = chainMaximum > 0 ? chainMaximum : dealMaximum;
        if(totalClaimed + amount > chainMaximum_) {
            amount = chainMaximum_ - totalClaimed;
        }

        if(amount > 0) {
            claimedAmount[tokenId] = amount;
            totalClaimed += amount;
            if(deliveryAmount > 0) {
                uint256 bonus = getDeliveryTokensFor(tokenId, maximum);
                if(bonus > 0) deliveryToken.safeTransfer(staker, bonus);
            }

            AccountV3TBD tokenBoundAccount = getTokenBoundAccount(tokenId);
            uint256 fee = amount.mulDiv(CLAIMING_FEE, PRECISION);

            tokenBoundAccount.send(sponsor, amount - fee);
            tokenBoundAccount.send(treasury, fee);

            emit Claim(staker, tokenId, amount);
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
    function getStakesTo(uint256 index) external view returns (StakeData[] memory) {
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
     * @dev bonus is in 1eN precision, where N is the decimals of the delivery token
     * @dev T = total amount to be delivered
     * @dev M = first bonus discount
     * @dev C = deal maximum
     * @dev L = last stake
     * @dev X = sum of previous stakes
     * @dev R = amount of delivery tokens received
     * @dev K1, K2, constants
     */
    function getDeliveryTokensFor(uint256 tokenId, uint256 maximum) public view returns(uint256) {
        if (tokenId >= _tokenId) return 0;

        uint256 L = stakedAmount[tokenId];
        uint256 T = deliveryAmount;
        uint256 M = multiple;
        uint256 C = maximum;

        if(T == 0 || L == 0 || M == 0) return 0;

        uint256 S = _totalStaked(tokenId);
        uint256 X = S - L;

        if(multiple == 1e18) { // if no discount
            return L * T / S; // stakedAmount * deliveryAmount / totalStaked
        }

        if (S > C) { // dealMaximum was reached - calculate bonus for a partial stake
            L = C > X ? C - X : 0;
        }

        uint256 lnM = intoUint256(ln(ud(M)));
        uint256 k1 = (T * 1e18) / lnM; // ends up with delivery decimals
        uint256 k2 = C * 1e18 / (M - 1e18); // ends up with escrow decimals
        uint256 k3 = 1e18 + (L * 1e18 / (X + k2)); // ends up with precision 1e18

        uint256 result = k1 * intoUint256(ln(ud(k3))) / 1e18; // result has delivery token decimals
        return result;
    }

    /**
     * @notice Get next available token id
     */
    function nextId() external view returns (uint256) {
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
    function _createTokenBoundAccount(address staker, uint256 tokenId) private returns(address) {
        bytes32 salt = bytes32(abi.encode(0));
        address payable walletAddress = payable(_registry.createAccount(_implementation, salt, block.chainid, address(this), tokenId));
        AccountV3TBD newAccount = AccountV3TBD(walletAddress);
        require(newAccount.owner() == staker, "SRG024");

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
        require(transferable, "SRG040");

        uint256 amount = stakedAmount[tokenId];        

        if(address(stakersWhitelist) != ADDRESS_ZERO){
            uint256 staked = stakes[to] + amount;
            require(stakersWhitelist.canStake(to, staked), "SRG041");
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

    /**
     * @notice Function to check claim requirements
     */
    function _canClaim() internal view {
        require(arbitrator == ADDRESS_ZERO || claimApproved, "SRG042");
        require(_claimId < _tokenId, "SRG043");
        require(state() == State.Claiming, "SRG044");
        require(_totalStaked(_tokenId) >= dealMinimum, "SRG045");
    }

    /**
     * @notice Function to check the deal can be configured
     */
    function _canConfigure() internal view {
        require(state() < State.Closed, "SRG047");
        if(state() == State.Claiming) {
            require(_totalStaked(_tokenId) < dealMinimum, "SRG046");
        }
    }

    /**
     * @notice Function to check the closing time is valid
     * @param closingTime_ The closing time to check
     */
    function _validClosingTime(uint256 closingTime_) internal view {
        require(closingTime_ == 0 || closingTime_ >= block.timestamp + closingDelay, "SRG016");
        require(closingTime_ <= block.timestamp + MAX_CLOSING_RANGE, "SRG016");
    }

    function _stake(address staker, uint256 amount) internal {
        require(state() == State.Active, "SRG036");
        require(amount > 0, "SRG015");
        uint256 currentStake = stakes[staker] + amount;

        if(address(stakersWhitelist) != ADDRESS_ZERO){
            require(stakersWhitelist.canStake(staker, currentStake), "SRG037");
        }

        uint256 newTokenId = _tokenId++;
        stakedAmount[newTokenId] = amount;
        stakes[staker] = currentStake;

        _safeMint(staker, newTokenId);
        address newAccount = _createTokenBoundAccount(staker, newTokenId);
        escrowToken.safeTransferFrom(msg.sender, newAccount, amount);

        emit Stake(staker, newAccount, newTokenId, amount);
    }
}
