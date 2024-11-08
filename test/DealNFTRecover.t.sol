// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";

contract DealNFTRecoverTest is Test, DealSetup {
    function setUp() public {
        _init();
        _setup();
        _configure();
        _activate();
    }

    function test_RevertWhen_RecoverWhenActive() public {
        _stake(staker1);

        assertEq(deal.totalStaked(), amount);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));

        vm.expectRevert("SRG039");
        vm.prank(staker1);
        deal.recover(0);
    }

    function test_RevertWhen_RecoverWhenClaiming() public {
        _stake(staker1);
        skip(15 days);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));

        vm.expectRevert("SRG039");
        vm.prank(staker1);
        deal.recover(0);
    }

    function test_RevertWhen_RecoverWithWrongOwner() public {
        _stake(staker1);

        vm.expectRevert("SRG022");
        vm.prank(staker2);
        deal.recover(0);
    }


    function test_RecoverAfterCanceled() public {
        _stake(staker1);
        assertEq(deal.totalStaked(), amount);

        vm.prank(sponsor);
        deal.cancel();
        assertEq(uint(deal.state()), uint256(DealNFT.State.Canceled));
        
        assertEq(escrowToken.balanceOf(address(deal.getTokenBoundAccount(0))), amount);
        assertEq(escrowToken.balanceOf(staker1), 0);

        vm.prank(staker1);
        deal.recover(0);

        assertEq(escrowToken.balanceOf(address(deal.getTokenBoundAccount(0))), 0);
        assertEq(escrowToken.balanceOf(staker1), amount);
    }

    function test_RecoverAfterClosed() public {
        _stake(staker1);

        skip(22 days);
        assertEq(uint(deal.state()), uint256(DealNFT.State.Closed));
        
        assertEq(escrowToken.balanceOf(address(deal.getTokenBoundAccount(0))), amount);
        assertEq(escrowToken.balanceOf(staker1), 0);

        vm.prank(staker1);
        deal.recover(0);

        assertEq(escrowToken.balanceOf(address(deal.getTokenBoundAccount(0))), 0);
        assertEq(escrowToken.balanceOf(staker1), amount);
    }
}
