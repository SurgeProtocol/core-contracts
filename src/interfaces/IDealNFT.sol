// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

interface IDealNFT {
    function sponsorAddress() external view returns (address);
    function escrowToken() external view returns (IERC20);
    function closingTimestamp() external view returns (uint256);
    function amountOf(uint256 tokenId) external view returns (uint256);
}
