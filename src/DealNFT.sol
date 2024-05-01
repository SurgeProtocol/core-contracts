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
    
    event Deal(address indexed sponsorAddress, address escrowToken, uint256 closingTimestamp);
    event Stake(address indexed staker, address indexed walletAddress, uint256 tokenId, uint256 amount);
    event Unstake(address indexed tokenBoundAccount, address indexed nftOwner, uint256 tokenId, uint256 amount);
    event Claim(address indexed sponsorAddress, uint256 tokenId, uint256 amount);

    uint256 private _tokenId;
    uint256 private claimTokenId;

    string private nftURI;
    
    IERC6551Registry private registry;
    AccountV3TBD private implementation;

    address public sponsorAddress;
    IERC20 public escrowToken;
    uint256 public closingTimestamp;

    uint256 public totalStaked;
    uint256 public totalClaimed;

    mapping(uint256 tokenId => uint256) public stakedAmount;
    mapping(uint256 tokenId => uint256) public claimedAmount;

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
        implementation = AccountV3TBD(implementation_);

        emit Deal(sponsorAddress, escrowToken_, closingTimestamp);
    }

    function stake(uint256 amount) external {
        uint256 newTokenId = _tokenId++;
        _safeMint(msg.sender, newTokenId);
        
        bytes32 salt = bytes32(abi.encode(0));
        address payable walletAddress = payable(registry.createAccount(address(implementation), salt, block.chainid, address(this), newTokenId));
        AccountV3TBD newAccount = AccountV3TBD(walletAddress);
        require(newAccount.owner() == msg.sender, "owner mismatch");
        newAccount.approve();

        escrowToken.safeTransferFrom(msg.sender, walletAddress, amount);

        stakedAmount[newTokenId] = amount;
        totalStaked += amount;

        emit Stake(msg.sender, walletAddress, newTokenId, amount);
    }

    function unstake(uint256 tokenId) external {
        address nftOwner = ownerOf(tokenId);
        require(msg.sender == nftOwner, "not the nft owner");
        require(!_isClosingWeek(), "cannot withdraw during closing week");

        totalStaked -= stakedAmount[tokenId];
        stakedAmount[tokenId] = 0;

        address tokenBoundAccount = getTokenBoundAccount(tokenId);
        uint256 balance = escrowToken.balanceOf(tokenBoundAccount);
        escrowToken.safeTransferFrom(tokenBoundAccount, nftOwner, balance);

        emit Unstake(tokenBoundAccount, nftOwner, tokenId, balance);
    }

    function claimNext() external {
        require(msg.sender == sponsorAddress, "not the sponsor");
        require(_isClosingWeek(), "not in closing week");
        require(claimTokenId < _tokenId, "token id out of bounds");

        _claimNext();
    }

    function claim() external {
        require(msg.sender == sponsorAddress, "not the sponsor");
        require(_isClosingWeek(), "not in closing week");
        require(claimTokenId < _tokenId, "token id out of bounds");

        while(claimTokenId < _tokenId) {
            _claimNext();
        }
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

    function _isClosingWeek() private view returns (bool) {
        return closingTimestamp < block.timestamp && block.timestamp < (closingTimestamp + 1 weeks);
    }

    function _claimNext() private {
        uint256 tokenId = claimTokenId++;
        uint256 amount = stakedAmount[tokenId];

        if(amount > 0) {
            // TODO: implement a total maximum deal amount. Take funds up to that number and then stop.
            // There will be a last stake with less claimed amount than the staked amount. All the stakes after that will unused - not sent to sponsor.
            escrowToken.safeTransferFrom(getTokenBoundAccount(tokenId), sponsorAddress, amount);
            claimedAmount[tokenId] = amount;
            totalClaimed += amount;
            // TODO: hook transfers rewards to TBA
        }

        emit Claim(sponsorAddress, tokenId, amount);
    }
}
