// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";

contract DealNFTStakeTest is Test, DealSetup {
    function setUp() public {
        _init();
        _setup();
        _configure();
    }

    function test_Stake() public {
        _activate();

        vm.prank(staker1);
        deal.stake(amount);
        tokenId = 0;

        assertEq(deal.stakedAmount(tokenId), amount);
        assertEq(deal.totalStaked(), amount);
        assertEq(
            escrowToken.balanceOf(deal.getTokenBoundAccount(tokenId)),
            amount
        );
        assertEq(escrowToken.balanceOf(staker1), 0);
        assertEq(deal.ownerOf(tokenId), staker1);

        vm.prank(staker2);
        deal.stake(amount);
        tokenId = 1;

        assertEq(deal.stakedAmount(tokenId), amount);
        assertEq(deal.totalStaked(), amount * 2);
        assertEq(
            escrowToken.balanceOf(deal.getTokenBoundAccount(tokenId)),
            amount
        );
        assertEq(escrowToken.balanceOf(staker2), 0);
        assertEq(deal.ownerOf(tokenId), staker2);
    }

    function test_RevertWhen_StakeBeforeActive() public {

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Setup));
        vm.expectRevert("not an active deal");
        vm.prank(staker1);
        deal.stake(amount);
    }

    function test_RevertWhen_StakeAfterActive() public {
        _activate();

        skip(15 days);

        vm.expectRevert("not an active deal");
        vm.prank(staker1);
        deal.stake(amount);
    }

    function test_RevertWhen_StakeZero() public {
        _activate();

        vm.expectRevert("invalid amount");
        vm.prank(staker1);
        deal.stake(0);
    }

}
