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

    function test_RevertWhen_ClaimNotArbitrator() public {
        vm.expectRevert(DealNFT.OnlyArbitrator.selector);
        vm.prank(staker1);
        deal.claim();
    }

    function test_RevertWhen_ClaimBeforeClosing() public {
        _stake(staker1);
        _stake(staker2);
        
        vm.expectRevert(DealNFT.NotInClaimingState.selector);
        vm.prank(arbitrator);
        deal.claim();
    }

    function test_RevertWhen_ClaimAfterClosed() public {
        _stake(staker1);
        _stake(staker2);
        skip(22 days);

        vm.expectRevert(DealNFT.NotInClaimingState.selector);
        vm.prank(arbitrator);
        deal.claim();
    }

    function test_RevertWhen_ClaimAfterCancelled() public {
        _stake(staker1);
        _stake(staker2);

        vm.prank(sponsor);
        deal.cancel();

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Cancelled));

        vm.expectRevert(DealNFT.NotInClaimingState.selector);
        vm.prank(arbitrator);
        deal.claim();
    }

    function test_RevertWhen_ClaimOutOfBounds() public {
        _depositDeliveryTokens();
        _stake(staker1);
        _stake(staker2);
        skip(15 days);

        vm.startPrank(arbitrator);
        deal.claim();
        
        vm.expectRevert(DealNFT.TokenOutOfBounds.selector);
        deal.claimNext();
        vm.stopPrank();
    }

    function test_RevertWhen_ClaimMinimumNotReached() public {
        vm.prank(sponsor);
        deal.configure("lorem ipsum", "https://social", "https://website", block.timestamp + 2 weeks, 2500000, 3000000, 1e18);
        _stake(staker1);
        _stake(staker2);
        skip(15 days);

        vm.expectRevert(DealNFT.MinimumNotReached.selector);
        vm.prank(arbitrator);
        deal.claim();
    }

    function test_RevertWhen_DepositDeliveryTokensNotArbitrator() public {
        vm.expectRevert(DealNFT.OnlyArbitrator.selector);
        vm.prank(staker1);
        deal.depositDeliveryTokens(address(0), 1);
    }

    function test_RevertWhen_RecoverDeliveryTokensNotArbitrator() public {
        vm.expectRevert(DealNFT.OnlyArbitrator.selector);
        vm.prank(staker1);
        deal.recoverDeliveryTokens();
    }

    function test_RevertWhen_StateIsNotClosed() public {
        vm.expectRevert(DealNFT.CannotRecover.selector);
        vm.prank(arbitrator);
        deal.recoverDeliveryTokens();
    }

    function test_RevertWhen_DeliveryTokenNotSet() public {
        vm.expectRevert(DealNFT.ZeroDetected.selector);
        vm.prank(arbitrator);
        deal.depositDeliveryTokens(address(0), 1);
    }
}
