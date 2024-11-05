// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IWhitelist} from "./interfaces/IWhitelist.sol";

contract Whitelists is IWhitelist {
    mapping(address staker => uint256) public stakesApprovals;
    mapping(address staker => bool) public claimsApprovals;

    address public sponsor;
    address public arbitrator;

    event StakerApproval(address indexed sponsor, address staker, uint256 amount);
    event BuyerApproval(address indexed sponsor, address staker, bool qualified);
    event ArbitratorChange(address indexed sponsor, address indexed arbitrator);

    modifier onlySponsor() {
        require(msg.sender == sponsor, "only sponsor");
        _;
    }

    modifier onlySponsorOrArbitrator() {
        require(msg.sender == sponsor || msg.sender == arbitrator, "only sponsor or arbitrator");
        _;
    }

    constructor(address sponsor_) {
        sponsor = sponsor_;
    }

    /**
     * @dev Set arbitrator address
     * @param arbitrator_ arbitrator address
     */
    function setArbitrator(address arbitrator_) external onlySponsor {
        arbitrator = arbitrator_;
        emit ArbitratorChange(sponsor, arbitrator_);
    }

    /**
     * @dev Approve staker to stake amount
     * @param staker_ staker address
     * @param amount_ amount to stake
     */
    function approveStaker(address staker_, uint256 amount_) external onlySponsorOrArbitrator {
        stakesApprovals[staker_] = amount_;
        emit StakerApproval(sponsor, staker_, amount_);
    }

    /**
     * @dev Approve multiple stakers to stake amounts
     * @param stakers staker addresses
     * @param amounts amounts to stake
     */
    function approveStakers(address[] memory stakers, uint256[] memory amounts) external onlySponsorOrArbitrator {
        require(stakers.length == amounts.length, "length mismatch");
        uint256 n = stakers.length;

        for (uint256 i = 0; i < n; ) {
            stakesApprovals[stakers[i]] = amounts[i];
            emit StakerApproval(sponsor, stakers[i], amounts[i]);
            unchecked { i++; }
        }
    }

    /**
     * @dev Approve staker to claim
     * @param staker_ staker address
     * @param qualified_ true if staker is qualified to claim
     */
    function approveBuyer(address staker_, bool qualified_) external onlySponsorOrArbitrator {
        claimsApprovals[staker_] = qualified_;
        emit BuyerApproval(sponsor, staker_, qualified_);
    }

    /**
     * @dev Approve multiple stakers to claim
     * @param stakers staker addresses
     * @param qualifieds true if staker is qualified to claim
     */
    function approveBuyers(address[] memory stakers, bool[] memory qualifieds) external onlySponsorOrArbitrator {
        require(stakers.length == qualifieds.length, "length mismatch");
        uint256 n = stakers.length;

        for (uint256 i = 0; i < n; ) {
            claimsApprovals[stakers[i]] = qualifieds[i];
            emit BuyerApproval(sponsor, stakers[i], qualifieds[i]);
            unchecked { i++; }
        }
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
