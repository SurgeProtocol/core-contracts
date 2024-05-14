// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";

contract DealNFTUnstakeTest is Test, DealSetup {
    function setUp() public {
        _init();

        _stakerApprovals();
        _tokenApprovals();

        _setup();
        _configure();
        _activate();
    }

    function test_Unstake() public {
        _stake(staker1);
        _stake(staker2);
        assertEq(deal.totalStaked(), amount * 2);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));

        vm.prank(staker1);
        deal.unstake(0);
        assertEq(deal.totalStaked(), amount);
        assertEq(deal.stakedAmount(tokenId), 0);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(tokenId)), 0);
        assertEq(escrowToken.balanceOf(staker1), amount);
    }

    function test_UnstakeAfterClosed() public {
        _stake(staker1);
        _stake(staker2);
        assertEq(deal.totalStaked(), amount * 2);

        vm.prank(staker1);
        deal.unstake(0);

        skip(22 days);
        assertEq(deal.totalStaked(), amount);
        assertEq(uint(deal.state()), uint256(DealNFT.State.Closed));

        vm.prank(staker2);
        deal.unstake(1);
        assertEq(deal.totalStaked(), amount);
        assertEq(deal.stakedAmount(1), amount);
    }

    function test_UnstakeAfterCanceled() public {
        _stake(staker1);
        assertEq(deal.totalStaked(), amount);

        vm.prank(sponsor);
        deal.cancel();
        assertEq(uint(deal.state()), uint256(DealNFT.State.Canceled));

        vm.prank(staker1);
        deal.unstake(0);
        assertEq(deal.totalStaked(), amount);
        assertEq(deal.stakedAmount(0), amount);
    }

    function test_RevertWhen_UnstakeWithWrongOwner() public {
        _stake(staker1);

        vm.expectRevert("not the nft owner");
        vm.prank(staker2);
        deal.unstake(0);
    }

    function test_RevertWhen_UnstakeWithClosingState() public {
        _stake(staker1);
        skip(15 days);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));

        vm.expectRevert("cannot unstake during closing week");
        vm.prank(staker1);
        deal.unstake(0);
    }
}
