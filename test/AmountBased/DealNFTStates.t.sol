// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../../src/DealNFT.sol";
import {DealSetupAmountBased} from "./DealSetupAmountBased.sol";

contract DealNFTStatesTest is Test, DealSetupAmountBased {
    function setUp() public {
        _init();
        _setup();
        _activate();
    }

    function test_State_Claiming() public {
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));

        _stake(staker1);
        tokenId = 0;
        assertEq(deal.stakedAmount(tokenId), amount);
        assertEq(escrowToken.balanceOf(staker1), 0);
        assertEq(deal.ownerOf(tokenId), staker1);
        assertEq(deal.totalStaked(), amount);
        assertEq(
            escrowToken.balanceOf(address(deal.getTokenBoundAccount(tokenId))),
            amount
        );

        _stake(staker2);
        tokenId = 1;
        assertEq(deal.stakedAmount(tokenId), amount);
        assertEq(escrowToken.balanceOf(staker2), 0);
        assertEq(deal.ownerOf(tokenId), staker2);
        assertEq(deal.totalStaked(), amount * 2);
        assertEq(
            escrowToken.balanceOf(address(deal.getTokenBoundAccount(tokenId))),
            amount
        );
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));
    }

    function test_State_Cancelled() public {
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));
        skip(1 weeks);
        _stake(staker1);
        _stake(staker2);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));
        skip(8 days);

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Cancelled));
    }

    function test_RevertWhen_StakeClaiming() public {
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));
        _stake(staker1);
        _stake(staker2);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));

        vm.expectRevert(DealNFT.NotActive.selector);
        _stake(staker1);
    }

    function test_RevertWhen_StakeAfterCancelled() public {
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));
        skip(1 weeks);
        _stake(staker1);
        _stake(staker2);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));
        skip(8 days);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Cancelled));

        vm.expectRevert(DealNFT.NotActive.selector);
        _stake(staker1);
    }

}
