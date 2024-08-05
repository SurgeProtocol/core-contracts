// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IWhitelist} from "./interfaces/IWhitelist.sol";

contract Whitelists is IWhitelist {
    mapping(address staker => uint256) public stakesApprovals;
    mapping(address staker => bool) public claimsApprovals;

    address public sponsor;

    event StakerApproval(address indexed sponsor, address staker, uint256 amount);
    event BuyerApproval(address indexed sponsor, address staker, bool qualified);

    modifier onlySponsor() {
        require(msg.sender == sponsor, "only sponsor");
        _;
    }

    constructor(address sponsor_) {
        sponsor = sponsor_;
    }

    /**
     * @dev Approve staker to stake amount
     * @param staker_ staker address
     * @param amount_ amount to stake
     */
    function approveStaker(address staker_, uint256 amount_) external onlySponsor {
        stakesApprovals[staker_] = amount_;
        emit StakerApproval(sponsor, staker_, amount_);
    }

    /**
     * @dev Approve staker to claim
     * @param staker_ staker address
     * @param qualified_ true if staker is qualified to claim
     */
    function approveBuyer(address staker_, bool qualified_) external onlySponsor {
        claimsApprovals[staker_] = qualified_;
        emit BuyerApproval(sponsor, staker_, qualified_);
    }

    /**
     * @dev Check if staker can stake amount
     * @param staker_ staker address
     * @param amount_ amount to stake
     * @return true if staker can stake amount
     */
    function canStake(
        address staker_,
        uint256 amount_
    ) external view override returns (bool) {
        return stakesApprovals[staker_] >= amount_;
    }

    /**
     * @dev Check if staker can claim
     * @param staker_ staker address
     * @return true if staker can claim
     */
    function canClaim(address staker_) external view override returns (bool) {
        return claimsApprovals[staker_];
    }
}
