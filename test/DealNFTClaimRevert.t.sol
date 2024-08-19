// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";

contract DealNFTClaimTest is Test, DealSetup {
    function setUp() public {
        _init();
        _setup();
        _configure();
        _activate();
    }

    function test_RevertWhen_ClaimNotSponsor() public {
        vm.expectRevert("SRG020");
        vm.prank(staker1);
        deal.claim();
    }

    function test_RevertWhen_ClaimBeforeClosing() public {
        _stake(staker1);
        _stake(staker2);
        
        vm.expectRevert("SRG044");
        vm.prank(sponsor);
        deal.claim();
    }

    function test_RevertWhen_ClaimAfterClosed() public {
        _stake(staker1);
        _stake(staker2);
        skip(22 days);

        vm.expectRevert("SRG044");
        vm.prank(sponsor);
        deal.claim();
    }

    function test_RevertWhen_ClaimAfterCanceled() public {
        _stake(staker1);
        _stake(staker2);

        vm.prank(sponsor);
        deal.cancel();

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Canceled));

        vm.expectRevert("SRG044");
        vm.prank(sponsor);
        deal.claim();
    }

    function test_RevertWhen_ClaimOutOfBounds() public {
        _transferRewards();
        _stake(staker1);
        _stake(staker2);
        skip(15 days);

        vm.startPrank(sponsor);
        deal.claim();
        
        vm.expectRevert("SRG043");
        deal.claimNext();
        vm.stopPrank();
    }

    function test_RevertWhen_ClaimMinimumNotReached() public {
        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 2500000, 3000000, address(0));
        _stake(staker1);
        _stake(staker2);
        skip(15 days);

        vm.expectRevert("SRG045");
        vm.prank(sponsor);
        deal.claim();
    }

    function test_RevertWhen_SetRewardTokenNotSponsor() public {
        vm.expectRevert("SRG020");
        vm.prank(staker1);
        deal.setRewardToken(address(0));
    }

    function test_RevertWhen_TransferRewardsNotSponsor() public {
        vm.expectRevert("SRG020");
        vm.prank(staker1);
        deal.transferRewards(1);
    }

    function test_RevertWhen_RecoverRewardsNotSponsor() public {
        vm.expectRevert("SRG020");
        vm.prank(staker1);
        deal.recoverRewards();
    }

    function test_RevertWhen_StateIsNotClosed() public {
        vm.expectRevert("SRG033");
        vm.prank(sponsor);
        deal.recoverRewards();
    }

    function test_RevertWhen_RewardsTokenNotSet() public {
        vm.expectRevert("SRG014");
        vm.prank(sponsor);
        deal.transferRewards(1);
    }
}
