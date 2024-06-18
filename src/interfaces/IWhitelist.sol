// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

interface IWhitelist {
    function claimsApprovals(address staker) external view returns (bool);
    function stakesApprovals(address staker) external view returns (uint256);
    //
    function canStake(address staker, uint256 amount) external view returns (bool);
    function canClaim(address staker) external view returns (bool);
}
