// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {Reader} from "../src/Reader.sol";
import {DealSetup} from "./DealSetup.sol";

import {IDeal} from "../src/interfaces/IDeal.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

contract ReaderTest is Test, DealSetup {
    Reader public reader;

    function setUp() public {
        reader = new Reader();
        _init();
    }

    function test_GetDeal() public {
        _initialize();
        IDeal.DealData memory deal = reader.getDeal(address(deal));
        IERC20Metadata escrow = IERC20Metadata(address(escrowToken));

        assertEq(deal.sponsor, sponsor);
        assertEq(deal.arbitrator, address(0));
        assertEq(address(deal.stakersWhitelist), address(0));
        assertEq(address(deal.claimsWhitelist), address(0));
        assertEq(address(deal.escrowToken), address(escrowToken));
        assertEq(address(deal.rewardToken), address(0));

        // assertEq(deal.closingTime, 0);
        assertEq(deal.closingDelay, 30 minutes);
        assertEq(deal.totalClaimed, 0);
        assertEq(deal.totalStaked, 2000000);
        assertEq(deal.multiplier, 5e18);
        assertEq(deal.dealMinimum, 0);
        assertEq(deal.dealMaximum, 2000000);
        assertEq(deal.unstakingFee, 50000);
        assertEq(deal.nextId, 2);
        assertEq(uint256(deal.state), uint256(DealNFT.State.Active));
        assertEq(deal.website, "https://test1.com");
        assertEq(deal.twitter, "https://test2.com");
        assertEq(deal.image, "https://test3.com");
        assertEq(deal.description, "desc");
        assertEq(deal.name, "SurgeDealTEST");
        assertEq(deal.symbol, "SRGTEST");

        assertEq(deal.escrowDecimals, escrow.decimals());
        assertEq(deal.escrowName, escrow.name());
        assertEq(deal.escrowSymbol, escrow.symbol());
        
        IDeal.StakeData[] memory stakes = deal.claimed;

        assertEq(stakes.length, 2);
        assertEq(stakes[0].owner, staker1);
        // assertEq(stakes[0].tba, address(deal.getTokenBoundAccount(0)));
        assertEq(stakes[0].staked, amount);
        assertEq(stakes[0].claimed, 0);

        assertEq(stakes[1].owner, staker2);
        // assertEq(stakes[1].tba, address(deal.getTokenBoundAccount(1)));
        assertEq(stakes[1].staked, amount);
        assertEq(stakes[1].claimed, 0);
    }

    function test_GetShortDeal() public {
        _initialize();
        IDeal.DealShortData memory deal = reader.getShortDeal(address(deal));
        assertEq(deal.name, "SurgeDealTEST");
        assertEq(deal.image, "https://test3.com");
        assertEq(deal.symbol, "SRGTEST");
        assertEq(uint256(deal.state), uint256(DealNFT.State.Active));
        assertEq(deal.description, "desc");
    }

    function test_GetDeal_EmptyDeal() public {
        IDeal.DealData memory deal = reader.getDeal(address(deal));

        assertEq(deal.sponsor, sponsor);
        assertEq(deal.arbitrator, address(0));
        assertEq(address(deal.stakersWhitelist), address(0));
        assertEq(address(deal.claimsWhitelist), address(0));
        assertEq(address(deal.escrowToken), address(0));
        assertEq(address(deal.rewardToken), address(0));

        // assertEq(deal.closingTime, 0);
        assertEq(deal.closingDelay, 0);
        assertEq(deal.totalClaimed, 0);
        assertEq(deal.totalStaked, 0);
        assertEq(deal.multiplier, 5e18);
        assertEq(deal.dealMinimum, 0);
        assertEq(deal.dealMaximum, 0);
        assertEq(deal.unstakingFee, 0);
        assertEq(deal.nextId, 0);
        assertEq(uint256(deal.state), uint256(DealNFT.State.Setup));
        assertEq(deal.website, "");
        assertEq(deal.twitter, "");
        assertEq(deal.image, "");
        assertEq(deal.description, "");
        assertEq(deal.name, "SurgeDealTEST");
        assertEq(deal.symbol, "SRGTEST");

        assertEq(deal.escrowDecimals, 6);
        assertEq(deal.escrowName, "");
        assertEq(deal.escrowSymbol, "");
    }

    function _initialize() internal {
        _setup();
        _configure();
        _activate();

        vm.prank(staker1);
        deal.stake(amount);

        vm.prank(staker2);
        deal.stake(amount);
    }
}