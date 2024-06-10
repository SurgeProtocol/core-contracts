// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

interface IDealNFT {
    function escrowToken() external view returns (IERC20);
    function allowToken(address to) external view returns (bool);
}
