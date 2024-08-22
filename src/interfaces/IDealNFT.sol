// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

interface IDealNFT {
    function escrowToken() external view returns (IERC20Metadata);
    function rewardToken() external view returns (IERC20Metadata);
    function allowToken(address to) external view returns (bool);
    function stake(address sender, uint256 amount) external;
}
