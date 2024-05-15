// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";

contract DealNFTTransferTest is Test, DealSetup {
    function setUp() public {
        _init();

        _stakerApprovals();
        _tokenApprovals();

        _setup();
        _configure();
        _activate();
    }

    function test_TransferNFT() public {
        vm.expectEmit(address(deal));
        emit DealNFT.Transferrable(sponsor, true);

        vm.prank(sponsor);
        deal.setTransferrable(true);

        _stake(staker1);
        assertEq(deal.ownerOf(tokenId), staker1);

        vm.prank(staker1);
        deal.transferFrom(staker1, staker2, tokenId);
        assertEq(deal.ownerOf(tokenId), staker2);

        assertEq(escrowToken.balanceOf(staker2), 1000000);
        vm.prank(staker2);
        deal.unstake(tokenId);
        assertEq(escrowToken.balanceOf(staker2), 1950000);
    }

    function test_RevertWhen_TransferNFT_toNotApproved() public {
        vm.prank(sponsor);
        deal.setTransferrable(true);

        _stake(staker1);

        vm.prank(sponsor);
        deal.approveStaker(staker2, amount-1);

        vm.expectRevert("insufficient approval");
        vm.prank(staker1);
        deal.transferFrom(staker1, staker2, tokenId);
    }

    function test_RevertWhen_TransferNFT() public {
        vm.prank(sponsor);
        deal.setTransferrable(false);
        _stake(staker1);
        assertEq(deal.ownerOf(tokenId), staker1);

        vm.expectRevert("not transferrable");
        vm.prank(staker1);
        deal.transferFrom(staker1, staker2, tokenId);
    }

}
