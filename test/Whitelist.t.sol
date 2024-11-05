// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Whitelists} from "../src/Whitelists.sol";

contract Whitelist is Test {
    address sponsor;
    address arbitrator;
    Whitelists whitelist;

    address staker1;
    address staker2;
    address staker3;

    function setUp() public {
        sponsor = vm.addr(1);
        arbitrator = vm.addr(2);

        staker1 = vm.addr(3);
        staker2 = vm.addr(4);
        staker3 = vm.addr(5);

        whitelist = new Whitelists(sponsor);
    }

    // ----------------------------------------
    function test_SetArbitrator() public {
        assertEq(whitelist.arbitrator(), address(0));
        _setArbitrator();
        assertEq(whitelist.arbitrator(), arbitrator);
    }

    function test_ApproveStaker() public {
        assertEq(whitelist.stakesApprovals(staker1), 0);
        _approveStaker(sponsor);
        assertEq(whitelist.stakesApprovals(staker1), 100);
    }

    function test_ApproveStakerArbitrator() public {
        assertEq(whitelist.stakesApprovals(staker1), 0);
        _setArbitrator();
        _approveStaker(arbitrator);
        assertEq(whitelist.stakesApprovals(staker1), 100);
    }

    function test_ApproveBuyer() public {
        assertEq(whitelist.claimsApprovals(staker1), false);
        _approveBuyer(sponsor);
        assertEq(whitelist.claimsApprovals(staker1), true);
    }

    function test_ApproveBayerArbitrator() public {
        assertEq(whitelist.claimsApprovals(staker1), false);
        _setArbitrator();
        _approveBuyer(arbitrator);
        assertEq(whitelist.claimsApprovals(staker1), true);
    }

    function test_ApproveMultipleStakers() public {
        assertEq(whitelist.stakesApprovals(staker1), 0);
        assertEq(whitelist.stakesApprovals(staker2), 0);
        assertEq(whitelist.stakesApprovals(staker3), 0);
        _approveMultipleStakers(sponsor);
        assertEq(whitelist.stakesApprovals(staker1), 100);
        assertEq(whitelist.stakesApprovals(staker2), 200);
        assertEq(whitelist.stakesApprovals(staker3), 300);
    }

    function test_ApproveMultipleStakersArbitrator() public {
        assertEq(whitelist.stakesApprovals(staker1), 0);
        assertEq(whitelist.stakesApprovals(staker2), 0);
        assertEq(whitelist.stakesApprovals(staker3), 0);
        _setArbitrator();
        _approveMultipleStakers(arbitrator);
        assertEq(whitelist.stakesApprovals(staker1), 100);
        assertEq(whitelist.stakesApprovals(staker2), 200);
        assertEq(whitelist.stakesApprovals(staker3), 300);
    }

    function test_ApproveMultipleBuyers() public {
        assertEq(whitelist.claimsApprovals(staker1), false);
        assertEq(whitelist.claimsApprovals(staker2), false);
        assertEq(whitelist.claimsApprovals(staker3), false);
        _approveMultipleBuyers(sponsor);
        assertEq(whitelist.claimsApprovals(staker1), true);
        assertEq(whitelist.claimsApprovals(staker2), true);
        assertEq(whitelist.claimsApprovals(staker3), true);
    }

    function test_ApproveMultipleBuyersArbitrator() public {
        assertEq(whitelist.claimsApprovals(staker1), false);
        assertEq(whitelist.claimsApprovals(staker2), false);
        assertEq(whitelist.claimsApprovals(staker3), false);
        _setArbitrator();
        _approveMultipleBuyers(arbitrator);
        assertEq(whitelist.claimsApprovals(staker1), true);
        assertEq(whitelist.claimsApprovals(staker2), true);
        assertEq(whitelist.claimsApprovals(staker3), true);
    }

    // ----------------------------------------
    function test_RevertWhen_SetArbitratorNotSponsor() public {
        vm.expectRevert("only sponsor");
        vm.prank(arbitrator);
        whitelist.setArbitrator(arbitrator);
    }

    function test_RevertWhen_ApproveStakerNotSponsorOrArbitrator() public {
        _setArbitrator();
        vm.expectRevert("only sponsor or arbitrator");
        _approveStaker(staker1);
    }

    function test_RevertWhen_ApproveBuyerNotSponsorOrArbitrator() public {
        _setArbitrator();
        vm.expectRevert("only sponsor or arbitrator");
        _approveBuyer(staker1);
    }

    function test_RevertWhen_ApproveMultipleStakersLengthMismatch() public {
        address[] memory stakers = new address[](3);
        uint256[] memory amounts = new uint256[](2);

        stakers[0] = staker1;
        stakers[1] = staker2;
        stakers[2] = staker3;
        amounts[0] = 100;
        amounts[1] = 200;

        vm.expectRevert("length mismatch");
        vm.prank(sponsor);
        whitelist.approveStakers(stakers, amounts);
    }

    function test_RevertWhen_ApproveMultipleBuyersLengthMismatch() public {
        address[] memory stakers = new address[](3);
        bool[] memory qualifieds = new bool[](2);

        stakers[0] = staker1;
        stakers[1] = staker2;
        stakers[2] = staker3;
        qualifieds[0] = true;
        qualifieds[1] = false;

        vm.expectRevert("length mismatch");
        vm.prank(sponsor);
        whitelist.approveBuyers(stakers, qualifieds);
    }

    function test_RevertWhen_ApproveMultipleStakersNotSponsorOrArbitrator() public {
        _setArbitrator();
        vm.expectRevert("only sponsor or arbitrator");
        _approveMultipleStakers(staker1);
    }

    // internal functions
    function _setArbitrator() public {
        vm.prank(sponsor);
        whitelist.setArbitrator(arbitrator);
    }

    function _approveStaker(address sender) public {
        vm.prank(sender);
        whitelist.approveStaker(staker1, 100);
    }

    function _approveBuyer(address sender) public {
        vm.prank(sender);
        whitelist.approveBuyer(staker1, true);
    }

    function _approveMultipleStakers(address sender) public {
        vm.prank(sender);
        address[] memory stakers = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        stakers[0] = staker1;
        stakers[1] = staker2;
        stakers[2] = staker3;
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;

        whitelist.approveStakers(stakers, amounts);
    }

    function _approveMultipleBuyers(address sender) public {
        vm.prank(sender);
        address[] memory stakers = new address[](3);
        bool[] memory qualifieds = new bool[](3);

        stakers[0] = staker1;
        stakers[1] = staker2;
        stakers[2] = staker3;
        qualifieds[0] = true;
        qualifieds[1] = true;
        qualifieds[2] = true;

        whitelist.approveBuyers(stakers, qualifieds);
    }
}