// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {Whitelists} from "../src/Whitelists.sol";
import {DealSetup} from "./DealSetup.sol";

contract DealNFTTransferTest is Test, DealSetup {
    function setUp() public {
        _init();
        _setup();
        _configure();
        _activate();
    }

    function test_TransferNFT() public {
        vm.expectEmit(address(deal));
        emit DealNFT.Transferable(true);

        vm.prank(sponsor);
        deal.setTransferable(true);

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
        Whitelists whitelist = new Whitelists(address(sponsor));

        vm.startPrank(sponsor);
        deal.setTransferable(true);
        deal.setStakersWhitelist(address(whitelist));
        deal.setClaimsWhitelist(address(whitelist));
        whitelist.approveStaker(staker1, amount);
        whitelist.approveStaker(staker2, amount-1);
        vm.stopPrank();

        _stake(staker1);

        vm.expectRevert("SRG041");
        vm.prank(staker1);
        deal.transferFrom(staker1, staker2, tokenId);
    }

    function test_RevertWhen_TransferNFT() public {
        vm.prank(sponsor);
        deal.setTransferable(false);
        _stake(staker1);
        assertEq(deal.ownerOf(tokenId), staker1);

        vm.expectRevert("SRG040");
        vm.prank(staker1);
        deal.transferFrom(staker1, staker2, tokenId);
    }

}
