// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";

contract DealNFTWhitelistsTest is Test, DealSetup {
    function setUp() public {
        _init();        
        _setup();
        _configure();
        _activate();
    }

    function test_SetWhitelists() public {
        assertEq(deal.whitelistStakes(), false);
        assertEq(deal.whitelistClaims(), false);

        vm.prank(sponsor);
        deal.setWhitelists(true, true);

        assertEq(deal.whitelistStakes(), true);
        assertEq(deal.whitelistClaims(), true);
    }

    function test_RevertWhen_SetWhitelistsWithWrongSender() public {
        vm.prank(staker1);
        vm.expectRevert("not the sponsor");
        deal.setWhitelists(true, true);
    }

    function test_StakingWithApproval() public {
        vm.prank(sponsor);
        deal.setWhitelists(true, false);

        vm.prank(sponsor);
        deal.approveStaker(staker1, amount);

        _stake(staker1);
    }

    function test_RevertWhen_StakingWithoutApproval() public {
        vm.prank(sponsor);
        deal.setWhitelists(true, false);

        vm.expectRevert("insufficient approval");
        _stake(staker1);
    }

    function test_SkipsUnqualifiedClaims() public {
        vm.prank(sponsor);
        deal.setWhitelists(false, true);

        _stake(staker1);
        _stake(staker2);

        assertEq(deal.totalStaked(), 0);
        vm.prank(sponsor);
        deal.approveBuyer(staker1, true);
        assertEq(deal.totalStaked(), amount);

        skip(15 days);
        vm.prank(sponsor);
        deal.claim();

        assertEq(escrowToken.balanceOf(sponsor), 970000);
    }
}
