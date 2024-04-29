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
    
    event Contribution(address indexed sender, address indexed walletAddress, address indexed nftContract, uint256 tokenId, uint256 amount);
    event DealCreated(address indexed sponsorAddress, address escrowToken, uint256 closingTimestamp);

    error OwnerMismatch();

    uint256 public _tokenId;
    string public nftURI;
    
    IERC6551Registry public registry;
    address public implementation;

    address public sponsorAddress;
    address public escrowToken;
    uint256 public closingTimestamp;

    uint256 public totalDeposited;

    mapping(uint256 tokenId => uint256) public amountOf;

    constructor(
        string memory nftURI_,
        address escrowToken_,
        uint256 closingTimestamp_,
        address registry_,
        address implementation_
    ) ERC721("SurgeDeal", "SRG") {
        nftURI = nftURI_;

        sponsorAddress = msg.sender;
        escrowToken = escrowToken_;
        closingTimestamp = closingTimestamp_;

        registry = IERC6551Registry(registry_);
        implementation = implementation_;

        emit DealCreated(sponsorAddress, escrowToken, closingTimestamp);
    }

    function mint(uint256 amount) external {
        uint256 newTokenId = _tokenId++;
        _safeMint(msg.sender, newTokenId);
        
        bytes32 salt = bytes32(abi.encode(0));
        address payable walletAddress = payable(registry.createAccount(implementation, salt, block.chainid, address(this), newTokenId));
        AccountV3Escrow newAccount = AccountV3Escrow(walletAddress);
        if (newAccount.owner() != msg.sender) revert OwnerMismatch();
        newAccount.approve();

        IERC20(escrowToken).safeTransferFrom(msg.sender, walletAddress, amount);

        amountOf[newTokenId] = amount;
        totalDeposited += amount;

        emit Contribution(msg.sender, walletAddress, address(this), newTokenId, amount);
    }

    // Returns the id of the next token without having to mint one.
    function nextId() external view returns (uint256) {
        return _tokenId;
    }

    // The following functions are overrides required by Solidity.
    function tokenURI(uint256) public view override returns (string memory) {
        return nftURI;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId) internal override {
        super._burn(tokenId);
    }

    function process(uint256[] memory tokenIds) external {
        if(isClosingWeek()) {
            require(msg.sender == sponsorAddress, "Invalid sponsor");
            
        }

        for(uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            IERC20(escrowToken).safeTransferFrom(getTBA(tokenId), sponsorAddress, amountOf[tokenId]);
            // TODO: hook transfers rewards to TBA
        }
    }

    function withdraw(uint256 tokenId, uint256 amount) external {
        if(!isClosingWeek()) {
            require(msg.sender == ownerOf(tokenId), "Invalid signer");
        }

        IERC20(escrowToken).safeTransferFrom(getTBA(tokenId), owner(), amount);
    }

    function getTBA(uint256 tokenId) public view returns(address) {
        return registry.account(implementation, bytes32(abi.encode(0)), block.chainid, address(this), tokenId);
    }

    function isClosingWeek() public view returns (bool) {
        return closingTimestamp < block.timestamp && block.timestamp < closingTimestamp + 1 weeks;
    }
}
