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
        IDeal.DealData memory _deal = reader.getDeal(address(deal));
        IERC20Metadata escrow = IERC20Metadata(address(escrowToken));

        assertEq(_deal.sponsor, sponsor);
        assertEq(_deal.arbitrator, arbitrator);
        assertEq(address(_deal.stakersWhitelist), address(0));
        assertEq(address(_deal.claimsWhitelist), address(0));
        assertEq(address(_deal.escrowToken), address(escrowToken));
        assertEq(address(_deal.deliveryToken), address(0));

        // assertEq(_deal.closingTime, 0);
        assertEq(_deal.closingDelay, 30 minutes);
        assertEq(_deal.totalClaimed, 0);
        assertEq(_deal.totalStaked, 2000000);
        assertEq(_deal.multiple, 5e18);
        assertEq(_deal.dealMinimum, 1000000);
        assertEq(_deal.dealMaximum, 2000000);
        assertEq(_deal.unstakingFee, 50000);
        assertEq(_deal.nextId, 2);
        assertEq(uint256(_deal.state), uint256(DealNFT.State.Active));
        assertEq(_deal.website, "https://website");
        assertEq(_deal.social, "https://social");
        assertEq(_deal.image, "https://image");
        assertEq(_deal.description, "desc");
        assertEq(_deal.name, "SurgeDealTEST");
        assertEq(_deal.symbol, "SRGTEST");

        assertEq(_deal.escrowDecimals, escrow.decimals());
        assertEq(_deal.escrowName, escrow.name());
        assertEq(_deal.escrowSymbol, escrow.symbol());
        
        IDeal.StakeData[] memory stakes = _deal.claimed;

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
        IDeal.DealShortData memory _deal = reader.getShortDeal(address(deal));
        assertEq(_deal.name, "SurgeDealTEST");
        assertEq(_deal.image, "https://image");
        assertEq(_deal.symbol, "SRGTEST");
        assertEq(uint256(_deal.state), uint256(DealNFT.State.Active));
        assertEq(_deal.description, "desc");
    }

    function test_GetDeal_EmptyDeal() public view {
        IDeal.DealData memory _deal = reader.getDeal(address(deal));

        assertEq(_deal.sponsor, sponsor);
        assertEq(_deal.arbitrator, arbitrator);
        assertEq(address(_deal.stakersWhitelist), address(0));
        assertEq(address(_deal.claimsWhitelist), address(0));
        assertEq(address(_deal.escrowToken), address(0));
        assertEq(address(_deal.deliveryToken), address(0));

        // assertEq(_deal.closingTime, 0);
        assertEq(_deal.closingDelay, 0);
        assertEq(_deal.totalClaimed, 0);
        assertEq(_deal.totalStaked, 0);
        assertEq(_deal.multiple, 1e18);
        assertEq(_deal.dealMinimum, 0);
        assertEq(_deal.dealMaximum, 0);
        assertEq(_deal.unstakingFee, 0);
        assertEq(_deal.deliveryType, 0);
        assertEq(_deal.nextId, 0);
        assertEq(uint256(_deal.state), uint256(DealNFT.State.Setup));
        assertEq(_deal.website, "");
        assertEq(_deal.social, "");
        assertEq(_deal.image, "https://image.jpg");
        assertEq(_deal.description, "");
        assertEq(_deal.name, "SurgeDealTEST");
        assertEq(_deal.symbol, "SRGTEST");

        assertEq(_deal.escrowDecimals, 6);
        assertEq(_deal.escrowName, "");
        assertEq(_deal.escrowSymbol, "");
    }

    function _initialize() internal {
        _setup();
        _configure();
        _activate();

        vm.prank(staker1);
        deal.stake(staker1, amount);

        vm.prank(staker2);
        deal.stake(staker2, amount);
    }
}