// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IWhitelist {
    function canStake(address staker, uint256 amount) external view returns (bool);
    function canTransfer(address from, address to, uint256 amount) external view returns (bool);
    function canClaim(address staker, uint256 amount) external view returns (bool);
}
