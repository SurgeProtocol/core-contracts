// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {AccountV3TBD} from "../src/AccountV3TBD.sol";
import "multicall-authenticated/Multicall3.sol";
import "erc6551/ERC6551Registry.sol";
import "tokenbound/src/AccountGuardian.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

import {DeliveryToken} from "./DeliveryToken.sol";
import {EscrowToken} from "./EscrowToken.sol";

contract DealNFTClaimTest is Test {
    DealNFT public deal;
    IERC20Metadata public escrowToken;
    IERC20Metadata public deliveryToken;

    uint256 amount = 100e8;
    address sponsor;
    address treasury;
    address staker1;
    address staker2;
    address staker3;
    address staker4;
    address staker5;
    address staker6;
    address staker7;

    function setUp() public {
        sponsor = vm.addr(1);
        treasury = vm.addr(2);
        staker1 = vm.addr(3);
        staker2 = vm.addr(4);
        staker3 = vm.addr(5);
        staker4 = vm.addr(6);
        staker5 = vm.addr(7);
        staker6 = vm.addr(8);
        staker7 = vm.addr(9);

        escrowToken = new EscrowToken("escrow", "escrow", 10000e8, address(this));
        deliveryToken = new DeliveryToken("reward", "reward", 10000e12, address(this));

        escrowToken.transfer(address(staker1), amount);
        escrowToken.transfer(address(staker2), amount);
        escrowToken.transfer(address(staker3), amount);
        escrowToken.transfer(address(staker4), amount);
        escrowToken.transfer(address(staker5), amount);
        escrowToken.transfer(address(staker6), amount);
        escrowToken.transfer(address(staker7), amount);
        deliveryToken.transfer(address(sponsor), 10000e12);

        ERC6551Registry registry = new ERC6551Registry();
        Multicall3 forwarder = new Multicall3();
        AccountGuardian guardian = new AccountGuardian(address(this));

        AccountV3TBD implementation = new AccountV3TBD(
            address(1),
            address(forwarder),
            address(registry),
            address(guardian)
        );

        deal = new DealNFT(
            address(registry),
            payable(address(implementation)),
            sponsor,
            treasury,
            "SurgeDealTEST",
            "SRGTEST",
            "https://test.com"
        );

        vm.prank(staker1);
        escrowToken.approve(address(deal), amount);
        vm.prank(staker2);
        escrowToken.approve(address(deal), amount);
        vm.prank(staker3);
        escrowToken.approve(address(deal), amount);
        vm.prank(staker4);
        escrowToken.approve(address(deal), amount);
        vm.prank(staker5);
        escrowToken.approve(address(deal), amount);
        vm.prank(staker6);
        escrowToken.approve(address(deal), amount);
        vm.prank(staker7);
        escrowToken.approve(address(deal), amount);

        vm.startPrank(sponsor);
        deal.setup(address(escrowToken), 30 minutes, 50000, "https://social", "https://website", "https://image", "desc");
        deal.configure("desc", "https://social", "https://website", block.timestamp + 2 weeks, 0, 2000000, address(0));
        deal.activate();
        vm.stopPrank();
    }

    function test_Claim() public {
        vm.startPrank(sponsor);
        deal.configure("desc", "https://social", "https://website", block.timestamp + 2 weeks, 50e8, 150e8, address(0));
        deal.setMultiple(5e18);
        deal.setDeliveryToken(address(deliveryToken));
        deliveryToken.approve(address(deal), 10000e12);
        deal.depositDeliveryTokens(10000e12);
        vm.stopPrank();

        _stake(staker1, amount);
        _stake(staker2, amount);
        assertEq(deal.totalStaked(), amount * 2);

        skip(15 days);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));

        vm.expectEmit(address(deal));
        emit DealNFT.Claim(staker1, 0, amount);
        vm.expectEmit(address(deal));
        emit DealNFT.Claim(staker2, 1, 50e8);

        vm.prank(sponsor);
        deal.claim();

        assertEq(deal.stakedAmount(0), amount);
        assertEq(deal.stakedAmount(1), amount);
        assertEq(escrowToken.balanceOf(address(deal.getTokenBoundAccount(0))), 0);
        assertEq(escrowToken.balanceOf(address(deal.getTokenBoundAccount(1))), 50e8);
        assertEq(escrowToken.balanceOf(sponsor), 1455e7);
        assertEq(escrowToken.balanceOf(treasury), 45e7);
        assertEq(deal.totalStaked(), 200e8);
        assertEq(deal.totalClaimed(), 150e8);
    }

    function test_ClaimWithManualDeliveredBonus() public {
        uint256 stakeAmount = 10e8;

        _setup(0);
        _stake(staker1, stakeAmount);
        _stake(staker2, stakeAmount*2);
        _stake(staker3, stakeAmount*3);

        skip(15 days);
        vm.prank(sponsor);
        deal.claim();

        assertEq(deal.stakedAmount(0), stakeAmount);
        assertEq(deal.stakedAmount(1), stakeAmount*2);
        assertEq(deal.stakedAmount(2), stakeAmount*3);
        assertEq(deal.claimedAmount(0), stakeAmount);
        assertEq(deal.claimedAmount(1), stakeAmount*2);
        assertEq(deal.claimedAmount(2), stakeAmount*3);
    }

    /*
        P = 1; C = 100; M = 5
        CA = ClaimedAmount
        SA = StakedAmount
        Id = NFT id
        ST = sum to

        CA	SA	ID	ST	IsumTo          Istake	        Deliver		
        10	10	0	0	575,6462732	    617,7053028	    42,05902958		
        10	10	1	10	617,7053028	    649,1196064	    31,41430354	
        20	20	2	20	649,1196064	    695,0852039	    45,96559752	
        10	10	3	40	695,0852039	    712,9728093	    17,88760546	
        30	30	4	50	712,9728093	    755,0318389	    42,05902958	
        10	10	5	80	755,0318389	    766,4033112	    11,37147228	
        10	20	6	90	766,4033112	    776,8260123	    10,42270112	
        TOTALS
        100	110	-	-	    -	            -	        201,17973908
    */
     function test_ClaimWithAutomatedDeliveredBonus() public {
        _setup(201179739080000);
        _stake(staker1, 10e8);
        _stake(staker2, 10e8);
        _stake(staker3, 20e8);
        _stake(staker4, 10e8);
        _stake(staker5, 30e8);
        _stake(staker6, 10e8);
        _stake(staker7, 20e8);

        uint256 maximum = deal.dealMaximum();
        uint256 bonus0 = deal.getDeliveryTokensFor(0, maximum);
        uint256 bonus1 = deal.getDeliveryTokensFor(1, maximum);
        uint256 bonus2 = deal.getDeliveryTokensFor(2, maximum);
        uint256 bonus3 = deal.getDeliveryTokensFor(3, maximum);
        uint256 bonus4 = deal.getDeliveryTokensFor(4, maximum);
        uint256 bonus5 = deal.getDeliveryTokensFor(5, maximum);
        uint256 bonus6 = deal.getDeliveryTokensFor(6, maximum);

        assertEq(deliveryToken.balanceOf(staker1), 0);
        assertEq(deliveryToken.balanceOf(staker2), 0);
        assertEq(deliveryToken.balanceOf(staker3), 0);
        assertEq(deliveryToken.balanceOf(staker4), 0);
        assertEq(deliveryToken.balanceOf(staker5), 0);
        assertEq(deliveryToken.balanceOf(staker6), 0);
        assertEq(deliveryToken.balanceOf(staker7), 0);

        skip(15 days);
        vm.prank(sponsor);
        deal.claim();

        assertEq(deliveryToken.balanceOf(staker1), bonus0);
        assertEq(deliveryToken.balanceOf(staker2), bonus1);
        assertEq(deliveryToken.balanceOf(staker3), bonus2);
        assertEq(deliveryToken.balanceOf(staker4), bonus3);
        assertEq(deliveryToken.balanceOf(staker5), bonus4);
        assertEq(deliveryToken.balanceOf(staker6), bonus5);
        assertEq(deliveryToken.balanceOf(staker7), bonus6);
    }

    /*
        P = 1; C = 100; M = 5
        CA = ClaimedAmount
        SA = StakedAmount
        Id = NFT id
        ST = sum to

        CA	SA	ID	ST	IsumTo          Istake	        Deliver
        10	10	0	0	575,6462732	    617,7053028	    40,54651081
        10	10	1	10	617,7053028	    649,1196064	    28,76820725
        20	20	2	20	649,1196064	    695,0852039	    40,54651081
        10	10	3	40	695,0852039	    712,9728093	    15,41506798
        30	30	4	50	712,9728093	    755,0318389	    35,66749439
        TOTALS
        100	110	-	-	    -	            -	        160,94379124
    */
     function test_ClaimWithAutomatedDeliveredBonus_WhenMaximumIsNotReached() public {
        _setup(160943791240000);
        _stake(staker1, 10e8);
        _stake(staker2, 10e8);
        _stake(staker3, 20e8);
        _stake(staker4, 10e8);
        _stake(staker5, 30e8);

        uint256 maximum = deal.totalStaked();
        uint256 bonus0 = deal.getDeliveryTokensFor(0, maximum);
        uint256 bonus1 = deal.getDeliveryTokensFor(1, maximum);
        uint256 bonus2 = deal.getDeliveryTokensFor(2, maximum);
        uint256 bonus3 = deal.getDeliveryTokensFor(3, maximum);
        uint256 bonus4 = deal.getDeliveryTokensFor(4, maximum);

        assertEq(deliveryToken.balanceOf(staker1), 0);
        assertEq(deliveryToken.balanceOf(staker2), 0);
        assertEq(deliveryToken.balanceOf(staker3), 0);
        assertEq(deliveryToken.balanceOf(staker4), 0);
        assertEq(deliveryToken.balanceOf(staker5), 0);

        skip(15 days);
        vm.prank(sponsor);
        deal.claim();

        assertEq(deliveryToken.balanceOf(staker1), bonus0);
        assertEq(deliveryToken.balanceOf(staker2), bonus1);
        assertEq(deliveryToken.balanceOf(staker3), bonus2);
        assertEq(deliveryToken.balanceOf(staker4), bonus3);
        assertEq(deliveryToken.balanceOf(staker5), bonus4);
    }

    function _setup(uint256 delivery) internal {
        vm.startPrank(sponsor);
        deal.configure("desc", "https://social", "https://website", block.timestamp + 2 weeks, 50e8, 100e8, address(0));
        deal.setDeliveryToken(address(deliveryToken));
        deal.setMultiple(5e18);
        deliveryToken.approve(address(deal), 10000e12);
        if(delivery > 0) deal.depositDeliveryTokens(delivery);
        vm.stopPrank();
    }

    function _stake(address staker, uint256 amount_) internal {
        vm.prank(staker);
        deal.stake(amount_);
    }
}
