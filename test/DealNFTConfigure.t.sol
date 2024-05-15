// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";

contract DealNFTConfigureTest is Test, DealSetup {
    function setUp() public {
        _init();

        _stakerApprovals();
        _tokenApprovals();
    }

    function test_Setup() public {
        // constructor params
        assertEq(deal.sponsor(), sponsor);
        assertEq(deal.name(), "SurgeDealTEST");
        assertEq(deal.symbol(), "SRGTEST");
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Setup));

        // defaults
        assertEq(deal.nextId(), 0);
        assertEq(deal.totalStaked(), 0);
        assertEq(deal.totalClaimed(), 0);

        // before setup
        assertEq(address(deal.escrowToken()), address(0));
        assertEq(deal.allowToken(address(escrowToken)), true);
        assertEq(deal.closingDelay(), 0);
        assertEq(deal.web(), "");
        assertEq(deal.twitter(), "");
        assertEq(deal.image(), "");

        _setup();

        // after setup
        assertEq(address(deal.escrowToken()), address(escrowToken));
        assertEq(deal.allowToken(address(escrowToken)), false);
        assertEq(deal.closingDelay(), 30 minutes);
        assertEq(deal.web(), "https://test1.com");
        assertEq(deal.twitter(), "https://test2.com");
        assertEq(deal.image(), "https://test3.com");
    }

    function test_Configure() public {
        _setup();

        // before config
        assertEq(deal.description(), "");
        assertEq(deal.closingTime(), 0);
        assertEq(deal.transferrable(), false);
        assertEq(deal.dealMinimum(), 0);
        assertEq(deal.dealMaximum(), 0);

        _configure();

        // after config
        assertEq(deal.description(), "desc");
        assertEq(deal.closingTime(), block.timestamp + 2 weeks);
        assertEq(deal.dealMinimum(), 0);
        assertEq(deal.dealMaximum(), 2000000);
        assertEq(deal.transferrable(), false);
    }

    function test_Activate() public {
        _setup();
        _configure();

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Setup));
        _activate();
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));
    }

    function test_ReconfigureWhenActive() public {
        _setup();
        _configure();
        _activate();
        
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));
        _configure();
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));
    }

    function test_ReconfigureMinimumNotReached() public {
        _setup();
        _activate();

        vm.prank(sponsor);
        deal.configure("a", block.timestamp + 2 weeks, 1, 1000);
        skip(18 days);

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));
        _configure();
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));
    }

    function test_RevertWhen_ConfigureWithWrongSender() public {
        vm.expectRevert("not the sponsor");
        vm.prank(staker1);
        deal.configure("a", block.timestamp + 2 weeks, 0, 1000);
    }

    function test_RevertWhen_ConfigureWithClosingTimeZero() public {
        vm.expectRevert("invalid closing time");
        vm.prank(sponsor);
        deal.configure("a", 0, 0, 1000);
    }

    function test_RevertWhen_ConfigureWithClosingTimeMinimum() public {
        vm.expectRevert("invalid closing time");
        vm.prank(sponsor);
        deal.configure("a", block.timestamp, 0, 1000);
    }

    function test_RevertWhen_ConfigureWithWrongRange() public {
        vm.expectRevert("wrong deal range");
        vm.prank(sponsor);
        deal.configure("a", block.timestamp + 2 weeks, 1000, 999);
    }

    function test_RevertWhen_ConfigureWhenClosed() public {
        _setup();
        _configure();
        _activate();
        skip(4 weeks);
        vm.expectRevert("cannot configure anymore");
        _configure();
    }

    function test_RevertWhen_ConfigureReopen_MinimumReached() public {
        _setup();
        _configure();
        _activate();

        _stake(staker1);
        skip(17 days);

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));
        vm.expectRevert("minimum stake reached");
        _configure();
    }
}
