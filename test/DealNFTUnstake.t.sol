// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";

contract DealNFTUnstakeTest is Test, DealSetup {
    function setUp() public {
        _init();
        _setup();
        _configure();
        _activate();
    }

    function test_Unstake() public {
        vm.prank(staker1);
        escrowToken.transfer(vm.addr(999), 20);

        vm.prank(staker1);
        escrowToken.approve(address(deal), 999980);

        vm.prank(staker1);
        deal.stake(999980);

        assertEq(deal.totalStaked(), 999980);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));

        vm.prank(staker1);
        deal.unstake(0);

        assertEq(deal.totalStaked(), 0);
        assertEq(deal.stakedAmount(0), 0);
        assertEq(escrowToken.balanceOf(address(deal.getTokenBoundAccount(tokenId))), 0);
        assertEq(escrowToken.balanceOf(staker1), 949981);
        assertEq(escrowToken.balanceOf(treasury), 24999);
    }


    function test_RevertWhen_UnstakeWithWrongOwner() public {
        _stake(staker1);

        vm.expectRevert("SRG022");
        vm.prank(staker2);
        deal.unstake(0);
    }

    function test_RevertWhen_UnstakeWithClosingState() public {
        _stake(staker1);
        skip(15 days);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));

        vm.expectRevert("SRG038");
        vm.prank(staker1);
        deal.unstake(0);
    }

    function test_RevertWhen_UnstakeAfterCanceled() public {
        _stake(staker1);
        assertEq(deal.totalStaked(), amount);

        vm.prank(sponsor);
        deal.cancel();
        assertEq(uint(deal.state()), uint256(DealNFT.State.Canceled));

        vm.expectRevert("SRG038");
        vm.prank(staker1);
        deal.unstake(0);
    }

    function test_RevertWhen_UnstakeAfterClosed() public {
        _stake(staker1);
        _stake(staker2);
        assertEq(deal.totalStaked(), amount * 2);

        vm.prank(staker1);
        deal.unstake(0);

        skip(22 days);
        assertEq(deal.totalStaked(), amount);
        assertEq(uint(deal.state()), uint256(DealNFT.State.Closed));

        vm.expectRevert("SRG038");

        vm.prank(staker2);
        deal.unstake(1);
    }
}
