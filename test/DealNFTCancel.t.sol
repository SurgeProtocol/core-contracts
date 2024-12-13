// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";

contract DealNFTCancelTest is Test, DealSetup {
    function setUp() public {
        _init();
        _setup();
        _configure();
    }

    function test_CancelBySponsor() public {
        vm.prank(sponsor);
        deal.cancel();
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Cancelled));
    }

    function test_CancelByArbitrator() public {
        vm.prank(sponsor);
        deal.configure("desc", "https://social", "https://website", block.timestamp + 2 weeks, 0, 2000000, 1e18);

        vm.prank(arbitrator);
        deal.cancel();
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Cancelled));
    }

    function test_RevertWhen_CancelWrongSponsorOrArbitrator() public {
        vm.expectRevert(DealNFT.NotAuthorized.selector);
        vm.prank(staker1);
        deal.cancel();
    }

    function test_CancelWhenClaiming() public {
        skip(15 days);
        assertEq(uint(deal.state()), uint256(DealNFT.State.Claiming));

        vm.prank(sponsor);
        deal.cancel();
        
        assertEq(uint(deal.state()), uint256(DealNFT.State.Cancelled));
    }

    function test_RevertWhen_CancelWhenCancelled() public {
        skip(15 days);

        vm.prank(sponsor);
        deal.cancel();

        assertEq(uint(deal.state()), uint256(DealNFT.State.Cancelled));

        vm.expectRevert(DealNFT.CannotCancel.selector);
        vm.prank(sponsor);
        deal.cancel();
    }
}
