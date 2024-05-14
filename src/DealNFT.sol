// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";
import {IERC6551Registry} from "erc6551/interfaces/IERC6551Registry.sol";
import {AccountV3TBD} from "./AccountV3TBD.sol";
import {IDealNFT} from "./interfaces/IDealNFT.sol";


/**
 * @title DealNFT
 * @notice Contract for managing NFT-based deals
 */
contract DealNFT is ERC721, IDealNFT, ReentrancyGuard {
    using Strings for address;
    using Strings for uint256;
    using SafeERC20 for IERC20;
    
    // Events
    event Deal(address indexed sponsor, string name, string symbol);
    event Setup(address sponsor, address escrowToken, uint256 closingDelay, string web, string twitter, string image);
    event Activate(address indexed sponsor);
    event Configure(address indexed sponsor, string description, uint256 closingTime, uint256 dealMinimum, uint256 dealMaximum);
    event Transferrable(address indexed sponsor, bool transferrable);
    event StakerApproval(address indexed sponsor, address staker, uint256 amount);
    event Cancel(address indexed sponsor);
    event Claim(address indexed sponsor, address indexed staker, uint256 tokenId, uint256 amount);
    event Stake(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);
    event Unstake(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);

    // Enum for deal states
    enum State { Setup, Active, Claiming, Closed, Canceled }

    uint256 public constant closingPeriod = 1 weeks;

    // Private state variables
    uint256 private _tokenId;
    uint256 private _claimId;
    State private _state;

    // Constructor parameters
    IERC6551Registry private immutable _registry;
    AccountV3TBD private immutable _implementation;
    string private _base;
    address public immutable sponsor;

    // Setup parameters
    IERC20 public escrowToken;
    uint256 public closingDelay;
    string public web;
    string public twitter;
    string public image;

    // Configuration parameters
    string public description;
    uint256 public closingTime;
    uint256 public dealMinimum;
    uint256 public dealMaximum;
    bool public transferrable;

    // Deal statistics
    uint256 public totalStaked;
    uint256 public totalClaimed;
    mapping(uint256 tokenId => uint256) public stakedAmount;
    mapping(uint256 tokenId => uint256) public claimedAmount;

    // Staker approvals
    mapping(address staker => uint256) public approvalOf;

    /**
     * @notice Constructor to initialize DealNFT contract
     * @param registry_ The address of the registry contract
     * @param implementation_ The address of the implementation contract
     * @param sponsor_ The address of the sponsor of the deal
     * @param name_ The name of the NFT
     * @param symbol_ The symbol of the NFT
     * @param baseURI_ The base URI for the NFTs
     */
    constructor(
        address registry_,
        address implementation_,
        address sponsor_,
        string memory name_,
        string memory symbol_,
        string memory baseURI_
    ) ERC721(name_, symbol_) {
        require(registry_ != address(0), "registry cannot be zero");
        require(implementation_ != address(0), "implementation cannot be zero");
        require(sponsor_ != address(0), "sponsor cannot be zero");
        require(bytes(name_).length > 0, "name cannot be empty");
        require(bytes(symbol_).length > 0, "symbol cannot be empty");
        require(bytes(baseURI_).length > 0, "baseURI cannot be empty");

        _registry = IERC6551Registry(registry_);
        _implementation = AccountV3TBD(payable(implementation_));

        sponsor = sponsor_;
        closingTime = type(uint256).max;

        _base = string(abi.encodePacked(
            baseURI_,
            "/chain/",
            block.chainid.toString(),
            "/deal/",
            address(this).toHexString(),
            "/token/"
        ));

        emit Deal(sponsor, name_, symbol_);
    }

    /**
     * @notice Modifier to check the caller is the sponsor
     */
    modifier onlySponsor() {
        require(msg.sender == sponsor, "not the sponsor");
        _;
    }

    /**
     * @notice modifier to check claim requirements
     */
    modifier canClaim() {
        require(_claimId < _tokenId, "token id out of bounds");
        require(state() == State.Claiming, "not in closing week");
        require(totalStaked >= dealMinimum, "minimum stake not reached");
        _;
    }

    /**
     * @notice Setup the deal
     * @param escrowToken_ The address of the escrow token
     * @param closingDelay_ The delay before closing the deal
     * @param web_ The website associated with the deal
     * @param twitter_ The Twitter account associated with the deal
     * @param image_ The image associated with the deal
     */
    function setup(
        address escrowToken_,
        uint256 closingDelay_,
        string memory web_,
        string memory twitter_,
        string memory image_
    ) external nonReentrant onlySponsor {
        require(state() == State.Setup, "cannot setup anymore");

        escrowToken = IERC20(escrowToken_);
        closingDelay = closingDelay_;
        web = web_;
        twitter = twitter_;
        image = image_;

        emit Setup(sponsor, address(escrowToken), closingDelay, web, twitter, image);
    }

    /**
     * @notice Activates the deal
     * @dev requires all setup parameters to be set
     */
    function activate() external nonReentrant onlySponsor {
        require(address(escrowToken) != address(0), "sponsor cannot be zero");
        require(closingDelay > 0, "closing delay cannot be zero");
        require(bytes(web).length > 0, "web cannot be empty");
        require(bytes(twitter).length > 0, "twitter cannot be empty");
        require(bytes(image).length > 0, "image cannot be empty");

        _state = State.Active;

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
        uint256 dealMaximum_
    ) external nonReentrant onlySponsor {
        require(closingTime_ > block.timestamp + closingDelay, "invalid closing time");
        require(dealMinimum_ <= dealMaximum_, "wrong deal range");
        require(state() < State.Closed, "cannot configure anymore");

        if(state() == State.Claiming) {
            require(totalStaked < dealMinimum, "minimum stake reached");
        }

        description = description_;
        closingTime = closingTime_;
        dealMinimum = dealMinimum_;
        dealMaximum = dealMaximum_;

        emit Configure(sponsor, description_, closingTime_, dealMinimum_, dealMaximum_);
    }

    /**
     * @notice Set whether the NFTs are transferrable or not
     * @param transferrable_ Boolean indicating if NFTs are transferrable
     */
    function setTransferrable(bool transferrable_) external nonReentrant onlySponsor {
        require(!_afterClosed(), "cannot be changed anymore");

        transferrable = transferrable_;
        emit Transferrable(sponsor, transferrable_);
    }

    /**
     * @notice Approve a staker to participate in the deal
     * @param staker_ The address of the staker to whitelist
     * @param amount_ The approval amount for the staker
     */
    function approveStaker(address staker_, uint256 amount_) external nonReentrant onlySponsor {
        approvalOf[staker_] = amount_;
        emit StakerApproval(sponsor, staker_, amount_);
    }

    /**
     * @notice Cancel the deal
     */
    function cancel() external nonReentrant onlySponsor {
        require(state() <= State.Active, "cannot be canceled");

        _state = State.Canceled;
        emit Cancel(sponsor);
    }

    /**
     * @notice Stake tokens into the deal
     * @param amount The amount of tokens to stake
     */
    function stake(uint256 amount) external nonReentrant {
        require(state() == State.Active, "not an active deal");
        require(amount > 0, "invalid amount");
        require(approvalOf[msg.sender] >= amount, "insufficient approval");

        require(escrowToken.allowance(msg.sender, address(this)) >= amount, "insufficient allowance");
        require(escrowToken.balanceOf(msg.sender) >= amount, "insufficient balance");

        uint256 newTokenId = _tokenId++;

        stakedAmount[newTokenId] = amount;
        totalStaked += amount;
        approvalOf[msg.sender] -= amount;

        _safeMint(msg.sender, newTokenId);
        address newAccount = _createTokenBoundAccount(newTokenId);
        escrowToken.safeTransferFrom(msg.sender, newAccount, amount);

        emit Stake(msg.sender, newAccount, newTokenId, amount);
    }

    /**
     * @notice Unstake tokens from the deal
     * @param tokenId The ID of the token to unstake
     */
    function unstake(uint256 tokenId) external nonReentrant {
        require(msg.sender == ownerOf(tokenId), "not the nft owner");
        require(state() != State.Claiming, "cannot unstake during closing week");

        uint256 amount = stakedAmount[tokenId];
        require(amount > 0, "nothing to unstake");

        address tokenBoundAccount = getTokenBoundAccount(tokenId);
        uint256 balance = escrowToken.balanceOf(tokenBoundAccount);
        require(balance >= amount, "insufficient balance");

        if(state() <= State.Active){
            totalStaked -= stakedAmount[tokenId];
            stakedAmount[tokenId] = 0;
        }

        escrowToken.safeTransferFrom(tokenBoundAccount, msg.sender, balance);

        emit Unstake(msg.sender, tokenBoundAccount, tokenId, balance);
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

        if(totalClaimed + amount > dealMaximum){
            amount = dealMaximum - totalClaimed;
        }

        if(amount > 0) {        
            claimedAmount[tokenId] = amount;
            totalClaimed += amount;
            // TODO: hook transfers rewards to TBA

            escrowToken.safeTransferFrom(getTokenBoundAccount(tokenId), sponsor, amount);

            emit Claim(sponsor, ownerOf(tokenId), tokenId, amount);
        }
    }

    /**
     * @notice Get current state of the deal
     * @dev a deal is considered closed if the tokens have been claimed by the sponsor
     */
    function state() public view returns (State) {
        if(_state == State.Canceled) return State.Canceled;
        if(_beforeClose()) return _state;
        if(_isClaimed() || _afterClosed()) return State.Closed;
        if(_isClosing()) return State.Claiming;

        revert("invalid state");
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
    function getTokenBoundAccount(uint256 tokenId) public view returns(address) {
        return _registry.account(address(_implementation), bytes32(abi.encode(0)), block.chainid, address(this), tokenId);
    }

    /**
     * @notice Create an account bound to the NFT
     */
    function _createTokenBoundAccount(uint256 tokenId) private returns(address) {
        bytes32 salt = bytes32(abi.encode(0));
        address payable walletAddress = payable(_registry.createAccount(address(_implementation), salt, block.chainid, address(this), tokenId));
        AccountV3TBD newAccount = AccountV3TBD(walletAddress);
        require(newAccount.owner() == msg.sender, "owner mismatch");
        newAccount.approve();

        return walletAddress;
    }

    /**
     * @notice Block escrow token from being interacted with from the TBA
     */
    function allowToken(address to) external view returns (bool) {
        return to != address(escrowToken);
    }

    /**
     * @notice Check if the deal is in the closing period
     */
    function _isClosing() private view returns (bool) {
        return !_beforeClose() && !_afterClosed();
    }

    /**
     * @notice Check if all tokens have been claimed by the sponsor
     */
    function _isClaimed() private view returns (bool) {
        return totalClaimed > 0 && (totalClaimed >= dealMaximum || totalClaimed >= totalStaked);
    }

    /**
     * @notice Check if the current time is before closing time
     */
    function _beforeClose() private view returns (bool) {
        return block.timestamp < closingTime;
    }

    /**
     * @notice Check if the current time is after closing time
     */
    function _afterClosed() private view returns (bool) {
        return block.timestamp > (closingTime + closingPeriod);
    }

    /**
     * @inheritdoc ERC721
     */
    function _transfer(address from, address to, uint256 tokenId) internal override {
        require(transferrable, "not transferrable");
        super._transfer(from, to, tokenId);
    }

    /**
     * @inheritdoc ERC721
     */
    function _baseURI() internal view override returns (string memory) {
        return _base;
    }
}
