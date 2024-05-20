// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";

contract DealNFTClaimTest is Test, DealSetup {
    function setUp() public {
        _init();
        _setup();
        _configure();
        _activate();
    }

    function test_Claim() public {
        vm.prank(sponsor);
        deal.configure("desc", block.timestamp + 2 weeks, 500000, 1500000, address(0));

        _stake(staker1);
        _stake(staker2);
        assertEq(deal.totalStaked(), amount * 2);

        skip(15 days);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));

        vm.expectEmit(address(deal));
        emit DealNFT.Claim(sponsor, staker1, 0, 1000000);
        vm.expectEmit(address(deal));
        emit DealNFT.Claim(sponsor, staker2, 1, 500000);

        vm.prank(sponsor);
        deal.claim();

        assertEq(deal.stakedAmount(0), amount);
        assertEq(deal.stakedAmount(1), amount);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(0)), 0);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(1)), 500000);
        assertEq(escrowToken.balanceOf(sponsor), 1455000);
        assertEq(escrowToken.balanceOf(treasury), 45000);
        assertEq(deal.totalStaked(), 2000000);
        assertEq(deal.totalClaimed(), 1500000);
    }

    function test_RevertWhen_ClaimNotSponsor() public {
        vm.expectRevert("not the sponsor");
        vm.prank(staker1);
        deal.claim();
    }

    function test_RevertWhen_ClaimBeforeClosing() public {
        _stake(staker1);
        _stake(staker2);
        
        vm.expectRevert("not in closing week");
        vm.prank(sponsor);
        deal.claim();
    }

    function test_RevertWhen_ClaimAfterClosed() public {
        _stake(staker1);
        _stake(staker2);
        skip(22 days);

        vm.expectRevert("not in closing week");
        vm.prank(sponsor);
        deal.claim();
    }

    function test_RevertWhen_ClaimAfterCanceled() public {
        _stake(staker1);
        _stake(staker2);

        vm.prank(sponsor);
        deal.cancel();

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Canceled));

        vm.expectRevert("not in closing week");
        vm.prank(sponsor);
        deal.claim();
    }

    function test_RevertWhen_ClaimOutOfBounds() public {
        _stake(staker1);
        _stake(staker2);
        skip(15 days);

        vm.startPrank(sponsor);
        deal.claim();
        
        vm.expectRevert("token id out of bounds");
        deal.claimNext();
        vm.stopPrank();
    }

    function test_RevertWhen_ClaimMinimumNotReached() public {
        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 2500000, 3000000, address(0));
        _stake(staker1);
        _stake(staker2);
        skip(15 days);

        vm.expectRevert("minimum stake not reached");
        vm.prank(sponsor);
        deal.claim();
    }
}
