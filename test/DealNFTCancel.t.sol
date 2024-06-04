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
        vm.expectEmit(address(deal));
        emit DealNFT.Cancel(sponsor);

        vm.prank(sponsor);
        deal.cancel();
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Canceled));
    }

    function test_CancelByArbitrator() public {
        address arbitrator = vm.addr(5);
        vm.prank(sponsor);
        deal.configure("desc", block.timestamp + 2 weeks, 0, 2000000, arbitrator);

        vm.expectEmit(address(deal));
        emit DealNFT.Cancel(sponsor);

        vm.prank(arbitrator);
        deal.cancel();
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Canceled));
    }

    function test_RevertWhen_CancelWrongSponsorOrArbitrator() public {
        vm.expectRevert("not the sponsor or arbitrator");
        vm.prank(staker1);
        deal.cancel();
    }

    function test_RevertWhen_CancelWhenClaiming() public {
        skip(15 days);
        assertEq(uint(deal.state()), uint256(DealNFT.State.Claiming));

        vm.expectRevert("cannot be canceled");
        vm.prank(sponsor);
        deal.cancel();
    }
}
