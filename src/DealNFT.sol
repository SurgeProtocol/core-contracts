// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC6551Registry} from "erc6551/interfaces/IERC6551Registry.sol";
import {AccountV3TBD} from "./AccountV3TBD.sol";
import {IDealNFT} from "./interfaces/IDealNFT.sol";

contract DealNFT is ERC721, Ownable, IDealNFT {
    using SafeERC20 for IERC20;
    
    event Deal(address indexed sponsor, address escrowToken);
    event Stake(address indexed staker, address indexed walletAddress, uint256 tokenId, uint256 amount);
    event Unstake(address indexed tokenBoundAccount, address indexed nftOwner, uint256 tokenId, uint256 amount);
    event Claim(address indexed sponsor, uint256 tokenId, uint256 amount);

    enum State { Configuration, Active, Closing, Closed, Canceled }

    uint256 private _tokenId;
    uint256 private _claimId;
    State private _state;

    IERC6551Registry private registry;
    AccountV3TBD private implementation;

    uint256 public constant closingPeriod = 1 weeks;

    // Hook hook; to store deal rules
    // whitelist or credentials for contributors;
    // vesting schedules for stakers on the reward tokens;
    // functionality for many escrow tokens

    address public sponsor;
    string public nftURI;
    string public web;
    string public twitter;
    IERC20 public escrowToken;
    uint256 public closingDelay;

    string public description;
    uint256 public closingDate;
    bool public transferrable;
    uint256 public dealMinimum;
    uint256 public dealMaximum;

    uint256 public totalStaked;
    uint256 public totalClaimed;
    mapping(uint256 tokenId => uint256) public stakedAmount;
    mapping(uint256 tokenId => uint256) public claimedAmount;

    constructor(
        address registry_,
        address payable implementation_,
        address sponsor_,
        string memory nftURI_,
        string memory web_,
        string memory twitter_,
        address escrowToken_,
        uint256 closingDelay_
    ) ERC721("SurgeDeal", "SRG") {
        registry = IERC6551Registry(registry_);
        implementation = AccountV3TBD(implementation_);

        sponsor = sponsor_;
        nftURI = nftURI_;
        web = web_;
        twitter = twitter_;
        escrowToken = IERC20(escrowToken_);
        closingDelay = closingDelay_;

        closingDate = type(uint256).max;

        emit Deal(sponsor, escrowToken_);
    }

    function configure(
        string memory description_,
        uint256 closingDate_,
        bool transferrable_,
        uint256 dealMinimum_,
        uint256 dealMaximum_
    ) external {
        require(msg.sender == sponsor, "not the sponsor");
        require(closingDate_ > block.timestamp + closingDelay, "invalid closing date");
        require(dealMinimum_ < dealMaximum_, "wrong stakes range");
        require(state() < State.Closed, "cannot configure anymore");

        if(state() == State.Closing) {
            require(totalStaked < dealMinimum, "minimum stake reached, cannot reopen");
        }

        description = description_;
        closingDate = closingDate_;
        transferrable = transferrable_;
        dealMinimum = dealMinimum_;
        dealMaximum = dealMaximum_;

        _state = State.Active;
    }

    function cancel() external {
        require(msg.sender == sponsor, "not the sponsor");
        require(state() <= State.Active, "cannot be canceled");
        _state = State.Canceled;
    }

    function stake(uint256 amount) external {
        require(state() == State.Active, "not an active deal");

        uint256 newTokenId = _tokenId++;
        _safeMint(msg.sender, newTokenId);

        address newAccount = _createTokenBoundAccount(newTokenId);
        escrowToken.safeTransferFrom(msg.sender, newAccount, amount);

        stakedAmount[newTokenId] = amount;
        totalStaked += amount;

        emit Stake(msg.sender, newAccount, newTokenId, amount);
    }

    function unstake(uint256 tokenId) external {
        address nftOwner = ownerOf(tokenId);
        require(msg.sender == nftOwner, "not the nft owner");
        require(state() != State.Closing, "cannot withdraw during closing week");

        if(state() <= State.Active){
            totalStaked -= stakedAmount[tokenId];
            stakedAmount[tokenId] = 0;
        }

        address tokenBoundAccount = getTokenBoundAccount(tokenId);
        uint256 balance = escrowToken.balanceOf(tokenBoundAccount);
        escrowToken.safeTransferFrom(tokenBoundAccount, nftOwner, balance);

        emit Unstake(tokenBoundAccount, nftOwner, tokenId, balance);
    }

    function claim() external {
        _checkClaim();

        while(_claimId < _tokenId) {
            _claimNext();
        }
    }

    function claimNext() external {
        _checkClaim();
        _claimNext();
    }

    function _checkClaim() private view {
        require(msg.sender == sponsor, "not the sponsor");
        require(state() == State.Closing, "not in closing week");
        require(_claimId < _tokenId, "token id out of bounds");
        require(totalStaked >= dealMinimum, "minimum stake not reached");
    }

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
            emit Claim(sponsor, tokenId, amount);
        }
    }

    function state() public view returns (State) {
        if(_state == State.Canceled) return State.Canceled;
        if(_beforeClose()) return _state;
        if(_isClosing()) return State.Closing;
        if(_afterClosed()) return State.Closed;

        revert("invalid state");
    }

    function nextId() public view returns (uint256) {
        return _tokenId;
    }

    function tokenURI(uint256) public view override returns (string memory) {
        return nftURI;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getTokenBoundAccount(uint256 tokenId) public view returns(address) {
        return registry.account(address(implementation), bytes32(abi.encode(0)), block.chainid, address(this), tokenId);
    }

    function _createTokenBoundAccount(uint256 tokenId) private returns(address) {
        bytes32 salt = bytes32(abi.encode(0));
        address payable walletAddress = payable(registry.createAccount(address(implementation), salt, block.chainid, address(this), tokenId));
        AccountV3TBD newAccount = AccountV3TBD(walletAddress);
        require(newAccount.owner() == msg.sender, "owner mismatch");
        newAccount.approve();

        return walletAddress;
    }

    function allowToken(address to) external view returns (bool) {
        return to != address(escrowToken);
    }

    function _isClosing() private view returns (bool) {
        return !_beforeClose() && !_afterClosed();
    }

    function _beforeClose() private view returns (bool) {
        return block.timestamp < closingDate;
    }

    function _afterClosed() private view returns (bool) {
        return block.timestamp > (closingDate + closingPeriod);
    }

    function _transfer(address from, address to, uint256 tokenId) internal override {
        require(transferrable, "not transferrable");
        super._transfer(from, to, tokenId);
    }
}
