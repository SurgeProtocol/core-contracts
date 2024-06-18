 // SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IWhitelist} from "./interfaces/IWhitelist.sol";

contract Whitelists is IWhitelist {

    mapping(address staker => uint256) public stakesApprovals;
    mapping(address staker => bool) public claimsApprovals;

    address public sponsor;

    modifier onlySponsor() {
        require(msg.sender == sponsor, "only sponsor");
        _;
    }

    constructor(address sponsor_) {
        sponsor = sponsor_;
    }

    function canStake(address staker, uint256 amount) external view returns (bool) {
        return stakesApprovals[staker] >= amount;
    }

    function canTransfer(address /*from*/, address to, uint256 amount) external view returns (bool) {
        return stakesApprovals[to] >= amount;
    }

    function canClaim(address staker, uint256 /*amount*/) external view returns (bool) {
        return claimsApprovals[staker];
    }

    function approveStaker(address staker_, uint256 amount_) external onlySponsor {
        stakesApprovals[staker_] = amount_;
    }

    function approveBuyer(address staker_, bool qualified_) external onlySponsor {
        claimsApprovals[staker_] = qualified_;
    }

}
