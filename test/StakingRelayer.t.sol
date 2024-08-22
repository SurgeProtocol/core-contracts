// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealSetup} from "./DealSetup.sol";
import {StakingRelayer} from "../src/StakingRelayer.sol";

contract StakingRelayerTest is Test, DealSetup {
    StakingRelayer public relayer;

    function setUp() public {
        _init();
        _setup();
        _configure();
        _activate();

        relayer = new StakingRelayer(treasury);
    }

    function test_StakeWithStakingRelayer() public {
        vm.prank(treasury);
        relayer.enableDeal(address(deal));

        _stake(staker1, amount);
        _stake(staker2, amount);

        assertEq(deal.ownerOf(0), staker1);
        assertEq(deal.ownerOf(1), staker2);
        assertEq(deal.stakedAmount(0), amount);
        assertEq(deal.stakedAmount(1), amount);
        assertEq(deal.totalStaked(), amount * 2);
        assertEq(
            escrowToken.balanceOf(address(deal.getTokenBoundAccount(0))),
            amount
        );
        assertEq(
            escrowToken.balanceOf(address(deal.getTokenBoundAccount(1))),
            amount
        );
        assertEq(escrowToken.balanceOf(staker1), 0);
        assertEq(escrowToken.balanceOf(staker2), 0);
    }

    function test_RevertWhen_StakeWithStakingRelayerBeforeEnable() public {
        vm.startPrank(staker1);
        escrowToken.approve(address(relayer), amount);

        vm.expectRevert("StakingRelayer: deal not allowed");
        relayer.stake(address(deal), amount);
        vm.stopPrank();
    }

    function test_RevertWhen_StakeWithoutApprovedToken() public {
        vm.prank(treasury);
        relayer.enableDeal(address(deal));
        vm.prank(staker1);
        escrowToken.approve(address(deal), amount);

        vm.expectRevert("ERC20: insufficient allowance");
        vm.prank(staker1);
        relayer.stake(address(deal), amount);
    }

    function test_RevertWhen_StakeWithStakingRelayerAfterDisable() public {
        vm.prank(treasury);
        relayer.enableDeal(address(deal));
        _stake(staker1, amount);

        vm.prank(treasury);
        relayer.disableDeal(address(deal));

        vm.startPrank(staker2);
        escrowToken.approve(address(relayer), amount);

        vm.expectRevert("StakingRelayer: deal not allowed");
        relayer.stake(address(deal), amount);
        vm.stopPrank();
    }

    function test_RevertWhen_enableWithWrongSender() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(staker1);
        relayer.enableDeal(address(deal));
    }

    function test_RevertWhen_disableWithWrongSender() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(staker1);
        relayer.disableDeal(address(deal));
    }

    function _stake(address staker, uint256 amount_) internal {
        vm.startPrank(staker);
        escrowToken.approve(address(relayer), amount_);
        relayer.stake(address(deal), amount_);
        vm.stopPrank();
    }
}