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
        deal.configure("desc", block.timestamp + 2 weeks, 0, amount, arbitrator);

        _stake(staker1);
        skip(15 days);
    }

    function test_ClaimWithArbitrator() public {
        vm.prank(arbitrator);
        deal.approveClaim();

        vm.prank(sponsor);
        deal.claim();

        assertEq(escrowToken.balanceOf(sponsor), 970000);
    }

    function test_RevertWhen_ApproveClaimNotArbitrator() public {
        vm.expectRevert("not the arbitrator");
        vm.prank(staker1);
        deal.approveClaim();
    }

    function test_RevertWhen_ClaimWithoutArbitratorApproval() public {
        vm.expectRevert("claim not approved");
        vm.prank(sponsor);
        deal.claim();
    }
}
