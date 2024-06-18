// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {Math} from "openzeppelin/utils/math/Math.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";
import {IERC6551Registry} from "erc6551/interfaces/IERC6551Registry.sol";
import {AccountV3TBD} from "./AccountV3TBD.sol";
import {IDealNFT} from "./interfaces/IDealNFT.sol";
import {IWhitelist} from "./interfaces/IWhitelist.sol";


/**
 * @title DealNFT
 * @notice Contract for managing NFT-based deals
 */
contract DealNFT is ERC721, IDealNFT, ReentrancyGuard {
    using Math for uint256;
    using Strings for address;
    using Strings for uint256;
    using SafeERC20 for IERC20;

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
    IERC20 public escrowToken;
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

    bool public transferable;
    bool public claimApproved;

    // Deal statistics
    uint256 public totalClaimed;
    mapping(uint256 tokenId => uint256) public stakedAmount;
    mapping(uint256 tokenId => uint256) public claimedAmount;

    // Whitelists
    address public stakersWhitelist;
    address public claimsWhitelist;


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
        require(totalStaked() >= dealMinimum, "minimum stake not reached");
        _;
    }

    /**
     * @notice Modifier to check the deal can be configured
     */
    modifier canConfigure() {
        require(state() < State.Closed, "cannot configure anymore");

        if(state() == State.Claiming) {
            require(totalStaked() < dealMinimum, "minimum stake reached");
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

        escrowToken = IERC20(escrowToken_);
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
    }

    /**
     * @notice Set the sponsor's Twitter handle
     * @param twitter_ The Twitter handle
     */
    function setTwitter(string memory twitter_) external nonReentrant onlySponsor canConfigure {
        twitter = twitter_;
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
    }

    /**
     * @notice Set the closing time of the deal
     * @param closingTime_ The closing time of the deal
     */
    function setClosingTime(uint256 closingTime_) external 
        nonReentrant onlySponsor canConfigure validClosingTime(closingTime_)
    {
        closingTime = closingTime_;
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
    }

    /**
     * @notice Set the arbitrator of the deal
     * @param arbitrator_ The address of the arbitrator
     */
    function setArbitrator(address arbitrator_) external nonReentrant onlySponsor canConfigure {
        arbitrator = arbitrator_;
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
        stakersWhitelist = whitelist_;
        emit SetStakersWhitelist(stakersWhitelist);
    }

    /**
     * @notice configure whitelists for staking
     * @param whitelist_ enable whitelisting on stakes
     */
    function setClaimsWhitelist(address whitelist_) external nonReentrant onlySponsor {
        claimsWhitelist = whitelist_;
        emit SetClaimsWhitelist(claimsWhitelist);
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

        if(stakersWhitelist != ADDRESS_ZERO){
            require(IWhitelist(stakersWhitelist).canStake(msg.sender, amount), "whitelist error");
        }

        uint256 newTokenId = _tokenId++;
        stakedAmount[newTokenId] = amount;

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
        while(_claimId < _tokenId) {
            _claimNext();
        }
    }

    /**
     * @notice Claim the next token id from the deal
     */
    function claimNext() external nonReentrant onlySponsor canClaim {
        _claimNext();
    }

    /**
     * @notice Internal function to claim the next token id from the deal
     * @dev funds are sent from the TBA to the sponsor until dealMaximum.
     */
    function _claimNext() private {
        uint256 tokenId = _claimId++;
        uint256 amount = stakedAmount[tokenId];
        address staker = ownerOf(tokenId);

        if(claimsWhitelist != ADDRESS_ZERO && !IWhitelist(claimsWhitelist).canClaim(staker, amount)) {
            return;
        }

        if(totalClaimed + amount > dealMaximum){
            amount = dealMaximum - totalClaimed;
        }

        if(amount > 0) {        
            claimedAmount[tokenId] = amount;
            totalClaimed += amount;
            // TODO: hook transfers rewards to TBA
            
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
    function totalStaked() public view returns (uint256 total) {
        for(uint256 i = 0; i < _tokenId; i++) {
            address staker = ownerOf(i);
            if(claimsWhitelist == ADDRESS_ZERO || IWhitelist(claimsWhitelist).canClaim(staker, stakedAmount[i])) {
                total += stakedAmount[i];
            }
        }
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
        return totalClaimed > 0 && (totalClaimed >= dealMaximum || totalClaimed >= totalStaked());
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

        if(stakersWhitelist != ADDRESS_ZERO){
            require(IWhitelist(stakersWhitelist).canTransfer(from, to, amount), "whitelist error");
        }

        super._transfer(from, to, tokenId);
    }

    /**
     * @inheritdoc ERC721
     */
    function _baseURI() internal view override returns (string memory) {
        return _base;
    }
}
