// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";

contract DealNFTClaimTest is Test, DealSetup {
    address arbitrator;
    
    function setUp() public {
        _init();
        _setup();
        _configure();
        _activate();

        arbitrator = vm.addr(9);

        vm.prank(sponsor);
        deal.configure("desc", block.timestamp + 2 weeks, amount, amount*2, arbitrator);

        _stake(staker1);
        _stake(staker2);
        skip(15 days);
        vm.prank(arbitrator);
        deal.approveClaim();
    }

    function test_ClaimWithArbitrator() public {
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));
        assertEq(deal.chainMaximum(), 0);
        assertEq(deal.dealMinimum(), amount);
        assertEq(deal.dealMaximum(), amount*2);
        assertEq(deal.totalStaked(), amount*2);

        vm.prank(arbitrator);
        deal.setChainMaximum(amount);

        vm.prank(sponsor);
        deal.claim();

        assertEq(deal.totalClaimed(), amount);
        assertEq(deal.chainMaximum(), amount);
        assertEq(deal.claimedAmount(0), amount);
        assertEq(deal.claimedAmount(1), 0);
    }

    function test_RevertWhen_SetChainMaximumNotArbitrator() public {
        vm.expectRevert("SRG021");
        vm.prank(staker1);
        deal.setChainMaximum(1);
    }
}
