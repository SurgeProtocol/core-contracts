// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC6551Registry} from "erc6551/interfaces/IERC6551Registry.sol";
import {AccountV3Escrow} from "./AccountV3Escrow.sol";
import {IDealNFT} from "./interfaces/IDealNFT.sol";

contract DealNFT is ERC721, Ownable, IDealNFT {
    using SafeERC20 for IERC20;
    
    event Deal(address indexed sponsorAddress, address escrowToken, uint256 closingTimestamp);
    event Stake(address indexed staker, address indexed walletAddress, uint256 tokenId, uint256 amount);
    event Unstake(address indexed tokenBoundAccount, address indexed nftOwner, uint256 tokenId, uint256 amount);
    event Close(address indexed sponsorAddress, uint256 tokenId, uint256 amount);

    error OwnerMismatch();

    uint256 private _tokenId;
    string public nftURI;
    
    IERC6551Registry public registry;
    AccountV3Escrow public implementation;

    address public sponsorAddress;
    IERC20 public escrowToken;
    uint256 public closingTimestamp;

    uint256 public totalDeposited;

    mapping(uint256 tokenId => uint256) public amountOf;

    constructor(
        string memory nftURI_,
        address escrowToken_,
        uint256 closingTimestamp_,
        address registry_,
        address payable implementation_,
        address sponsorAddress_
    ) ERC721("SurgeDeal", "SRG") {
        nftURI = nftURI_;

        sponsorAddress = sponsorAddress_;
        escrowToken = IERC20(escrowToken_);
        closingTimestamp = closingTimestamp_;

        registry = IERC6551Registry(registry_);
        implementation = AccountV3Escrow(implementation_);

        emit Deal(sponsorAddress, escrowToken_, closingTimestamp);
    }

    function stake(uint256 amount) external {
        uint256 newTokenId = _tokenId++;
        _safeMint(msg.sender, newTokenId);
        
        bytes32 salt = bytes32(abi.encode(0));
        address payable walletAddress = payable(registry.createAccount(address(implementation), salt, block.chainid, address(this), newTokenId));
        AccountV3Escrow newAccount = AccountV3Escrow(walletAddress);
        if (newAccount.owner() != msg.sender) revert OwnerMismatch();
        newAccount.approve();

        escrowToken.safeTransferFrom(msg.sender, walletAddress, amount);

        amountOf[newTokenId] = amount;
        totalDeposited += amount;

        emit Stake(msg.sender, walletAddress, newTokenId, amount);
    }

    function unstake(uint256 tokenId, uint256 amount) external {
        address nftOwner = ownerOf(tokenId);
        require(msg.sender == nftOwner, "Not NFT owner");
        require(!isClosingWeek(), "Cannot withdraw during closing week");

        uint256 balance = amountOf[tokenId];
        amountOf[tokenId] = balance > amount ? balance - amount : 0;
        totalDeposited -= (balance - amountOf[tokenId]);

        address tokenBoundAccount = getTokenBoundAccount(tokenId);
        escrowToken.safeTransferFrom(tokenBoundAccount, nftOwner, amount);

        emit Unstake(tokenBoundAccount, nftOwner, tokenId, amount);
    }

    function close(uint256[] memory tokenIds) external {
        require(msg.sender == sponsorAddress, "Invalid sponsor");
        require(isClosingWeek(), "Not in closing week");

        for(uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 amount = amountOf[tokenId];
            amountOf[tokenId] = 0;
            totalDeposited -= amount;
            escrowToken.safeTransferFrom(getTokenBoundAccount(tokenId), sponsorAddress, amount);
            // TODO: hook transfers rewards to TBA

            emit Close(sponsorAddress, tokenId, amount);
        }
    }

    function nextId() external view returns (uint256) {
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

    function isClosingWeek() public view returns (bool) {
        return closingTimestamp < block.timestamp && block.timestamp < (closingTimestamp + 1 weeks);
    }

}
