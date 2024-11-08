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
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Canceled));
    }

    function test_CancelByArbitrator() public {
        address arbitrator = vm.addr(5);
        vm.prank(sponsor);
        deal.configure("desc", "https://social", "https://website", block.timestamp + 2 weeks, 0, 2000000, arbitrator);

        vm.prank(arbitrator);
        deal.cancel();
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Canceled));
    }

    function test_RevertWhen_CancelWrongSponsorOrArbitrator() public {
        vm.expectRevert("SRG023");
        vm.prank(staker1);
        deal.cancel();
    }

    function test_RevertWhen_CancelWhenClaiming() public {
        skip(15 days);
        assertEq(uint(deal.state()), uint256(DealNFT.State.Claiming));

        vm.expectRevert("SRG035");
        vm.prank(sponsor);
        deal.cancel();
    }
}
