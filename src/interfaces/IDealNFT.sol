// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IDealNFT {
    function sponsorAddress() external view returns (address);
    function escrowToken() external view returns (address);
    function closingTimestamp() external view returns (uint256);
    function amountOf(uint256 tokenId) external view returns (uint256);
}
