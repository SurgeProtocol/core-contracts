// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {IERC6551Registry} from "erc6551/interfaces/IERC6551Registry.sol";
import {AccountV3TBD} from "./AccountV3TBD.sol";
import {IDealNFT} from "./interfaces/IDealNFT.sol";


/**
 * @title DealNFT
 * @notice Contract for managing NFT-based deals
 */
contract DealNFT is ERC721, IDealNFT {
    using Strings for address;
    using Strings for uint256;
    using SafeERC20 for IERC20;
    
    // Events
    event Deal(address indexed sponsor, address escrowToken);
    event Configure(address indexed sponsor, string description, uint256 closingTime, uint256 dealMinimum, uint256 dealMaximum);
    event Transferrable(address indexed sponsor, bool transferrable);
    event StakerApproval(address indexed sponsor, address staker, uint256 amount);
    event Cancel(address indexed sponsor);
    event Claim(address indexed sponsor, address indexed staker, uint256 tokenId, uint256 amount);
    event Stake(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);
    event Unstake(address indexed staker, address tokenBoundAccount, uint256 tokenId, uint256 amount);

    // Enum for deal states
    enum State { Configuration, Active, Closing, Closed, Canceled }

    // Private state variables
    uint256 private _tokenId;
    uint256 private _claimId;
    State private _state;

    // External contracts
    IERC6551Registry private _registry;
    AccountV3TBD private _implementation;

    // Deal parameters
    address public sponsor;
    string public baseURI;
    string public web;
    string public twitter;
    IERC20 public escrowToken;
    uint256 public closingDelay;
    uint256 public constant closingPeriod = 1 weeks;

    string public description;
    uint256 public closingTime;
    bool public transferrable;
    uint256 public dealMinimum;
    uint256 public dealMaximum;

    // Deal statistics
    uint256 public totalStaked;
    uint256 public totalClaimed;
    mapping(uint256 tokenId => uint256) public stakedAmount;
    mapping(uint256 tokenId => uint256) public claimedAmount;

    // Staker approvals
    mapping(address staker => uint256) public approvalOf;
    mapping(address staker => uint256) public stakeOf;

    /**
     * @notice Constructor to initialize DealNFT contract
     * @param registry_ The address of the ERC6551 registry
     * @param implementation_ The address of the AccountV3TBD implementation
     * @param sponsor_ The address of the sponsor of the deal
     * @param baseURI_ The base URI for the NFTs
     * @param web_ The website associated with the deal
     * @param twitter_ The Twitter account associated with the deal
     * @param escrowToken_ The address of the escrow token
     * @param closingDelay_ The delay before closing the deal
     */
    constructor(
        address registry_,
        address payable implementation_,
        address sponsor_,
        string memory baseURI_,
        string memory web_,
        string memory twitter_,
        address escrowToken_,
        uint256 closingDelay_
    ) ERC721("SurgeDealTEST", "SRGTEST") {
        _registry = IERC6551Registry(registry_);
        _implementation = AccountV3TBD(implementation_);

        sponsor = sponsor_;
        baseURI = string(abi.encodePacked(baseURI_, "/chain/", block.chainid.toString(), "/deal/", address(this).toHexString(), "/token/"));
        web = web_;
        twitter = twitter_;
        escrowToken = IERC20(escrowToken_);
        closingDelay = closingDelay_;

        closingTime = type(uint256).max;

        emit Deal(sponsor, escrowToken_);
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
    ) external {
        require(msg.sender == sponsor, "not the sponsor");
        require(closingTime_ > block.timestamp + closingDelay, "invalid closing time");
        require(dealMinimum_ < dealMaximum_, "wrong deal range");
        require(state() < State.Closed, "cannot configure anymore");

        if(state() == State.Closing) {
            require(totalStaked < dealMinimum, "minimum stake reached");
        }

        description = description_;
        closingTime = closingTime_;
        dealMinimum = dealMinimum_;
        dealMaximum = dealMaximum_;

        _state = State.Active;

        emit Configure(sponsor, description_, closingTime_, dealMinimum_, dealMaximum_);
    }

    /**
     * @notice Set whether the NFTs are transferrable or not
     * @param transferrable_ Boolean indicating if NFTs are transferrable
     */
    function setTransferrable(bool transferrable_) external {
        require(msg.sender == sponsor, "not the sponsor");
        require(!_afterClosed(), "cannot be changed anymore");

        transferrable = transferrable_;
        emit Transferrable(sponsor, transferrable_);
    }

    /**
     * @notice Approve a staker to participate in the deal
     * @param staker_ The address of the staker to whitelist
     * @param amount_ The approval amount for the staker
     */
    function approveStaker(address staker_, uint256 amount_) external {
        require(msg.sender == sponsor, "not the sponsor");

        approvalOf[staker_] = amount_;
        emit StakerApproval(sponsor, staker_, amount_);
    }

    /**
     * @notice Cancel the deal
     */
    function cancel() external {
        require(msg.sender == sponsor, "not the sponsor");
        require(state() <= State.Active, "cannot be canceled");

        _state = State.Canceled;
        emit Cancel(sponsor);
    }

    /**
     * @notice Stake tokens into the deal
     * @param amount The amount of tokens to stake
     */
    function stake(uint256 amount) external {
        require(state() == State.Active, "not an active deal");
        require(amount > 0, "invalid amount");
        require(approvalOf[msg.sender] >= stakeOf[msg.sender] + amount, "insufficient approval");

        uint256 newTokenId = _tokenId++;
        _safeMint(msg.sender, newTokenId);

        address newAccount = _createTokenBoundAccount(newTokenId);
        escrowToken.safeTransferFrom(msg.sender, newAccount, amount);

        stakedAmount[newTokenId] = amount;
        totalStaked += amount;
        stakeOf[msg.sender] += amount;

        emit Stake(msg.sender, newAccount, newTokenId, amount);
    }

    /**
     * @notice Unstake tokens from the deal
     * @param tokenId The ID of the token to unstake
     */
    function unstake(uint256 tokenId) external {
        require(msg.sender == ownerOf(tokenId), "not the nft owner");
        require(state() != State.Closing, "cannot withdraw during closing week");

        if(state() <= State.Active){
            stakeOf[msg.sender] -= stakedAmount[tokenId];
            totalStaked -= stakedAmount[tokenId];
            stakedAmount[tokenId] = 0;
        }

        address tokenBoundAccount = getTokenBoundAccount(tokenId);
        uint256 balance = escrowToken.balanceOf(tokenBoundAccount);
        escrowToken.safeTransferFrom(tokenBoundAccount, msg.sender, balance);

        emit Unstake(msg.sender, tokenBoundAccount, tokenId, balance);
    }

    /**
     * @notice Claim tokens from the deal
     */
    function claim() external {
        _checkClaim();

        while(_claimId < _tokenId) {
            _claimNext();
        }
    }

    /**
     * @notice Claim the next token id from the deal
     */
    function claimNext() external {
        _checkClaim();
        _claimNext();
    }

    /**
     * @notice Internal function to check claim requirements
     */
    function _checkClaim() private view {
        require(msg.sender == sponsor, "not the sponsor");
        require(_claimId < _tokenId, "token id out of bounds");
        require(state() == State.Closing, "not in closing week");
        require(totalStaked >= dealMinimum, "minimum stake not reached");
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
            escrowToken.safeTransferFrom(getTokenBoundAccount(tokenId), sponsor, amount);
            claimedAmount[tokenId] = amount;
            totalClaimed += amount;
            // TODO: hook transfers rewards to TBA

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
        if(_isClosing()) return State.Closing;

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
     * @notice Move approval and stake from one account to the other
     */
    function _transfer(address from, address to, uint256 tokenId) internal override {
        require(transferrable, "not transferrable");

        uint256 amount = stakedAmount[tokenId];

        approvalOf[from] -= amount;
        approvalOf[to] += amount;

        stakeOf[from] -= amount;
        stakeOf[to] += amount;

        super._transfer(from, to, tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}
