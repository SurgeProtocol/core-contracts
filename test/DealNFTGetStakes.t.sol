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
        _activate();

        vm.prank(staker1);
        deal.stake(amount);
        vm.prank(staker2);
        deal.stake(amount);
    }

    function test_GetStakes() public view {
        uint256 index = 1;
        DealNFT.StakeData[] memory stakes = deal.getStakesTo(index);

        assertEq(stakes[0].owner, staker1);
        assertEq(stakes[0].tba, address(deal.getTokenBoundAccount(0)));
        assertEq(stakes[0].staked, amount);
        assertEq(stakes[0].claimed, 0);
    }

    function test_GetStakesOverRange() public view {
        uint256 index = 10;
        DealNFT.StakeData[] memory stakes = deal.getStakesTo(index);

        assertEq(stakes.length, 2);
        assertEq(stakes[0].owner, staker1);
        assertEq(stakes[0].tba, address(deal.getTokenBoundAccount(0)));
        assertEq(stakes[0].staked, amount);
        assertEq(stakes[0].claimed, 0);

        assertEq(stakes[1].owner, staker2);
        assertEq(stakes[1].tba, address(deal.getTokenBoundAccount(1)));
        assertEq(stakes[1].staked, amount);
        assertEq(stakes[1].claimed, 0);
    }
}
