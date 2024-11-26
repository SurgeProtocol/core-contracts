// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

contract DealNFTConfigureTest is Test, DealSetup {
    function setUp() public {
        _init();
    }

    function test_Setup() public {
        assertEq(deal.name(), "SurgeDealTEST");
        assertEq(deal.symbol(), "SRGTEST");
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Setup));

        // defaults
        assertEq(deal.nextId(), 0);
        assertEq(deal.totalStaked(), 0);
        assertEq(deal.totalClaimed(), 0);

        // before setup
        DealNFT.Configuration memory configBefore = deal.getConfiguration();
        assertEq(configBefore.sponsor, sponsor);
        assertEq(address(configBefore.escrowToken), address(0));
        assertEq(deal.allowToken(address(escrowToken)), true);
        assertEq(configBefore.closingDelay, 0);
        assertEq(configBefore.website, "");
        assertEq(configBefore.social, "");
        assertEq(configBefore.image, "https://image.jpg");

        _setup();

        // after setup
        DealNFT.Configuration memory configAfter = deal.getConfiguration();
        assertEq(address(configAfter.escrowToken), address(escrowToken));
        assertEq(deal.allowToken(address(escrowToken)), false);
        assertEq(configAfter.closingDelay, 30 minutes);
        assertEq(configAfter.social, "https://social");
        assertEq(configAfter.website, "https://website");
        assertEq(configAfter.image, "https://image");
    }

    function test_Configure() public {
        _setup();

        // before config
        DealNFT.Configuration memory configBefore = deal.getConfiguration();
        assertEq(configBefore.description, "");
        assertEq(configBefore.closingTime, 0);
        assertEq(configBefore.transferable, false);
        assertEq(configBefore.dealMinimum, 0);
        assertEq(configBefore.dealMaximum, 0);

        _configure();

        // after config
        DealNFT.Configuration memory configAfter = deal.getConfiguration();
        assertEq(configAfter.description, "desc");
        assertEq(configAfter.closingTime, block.timestamp + 2 weeks);
        assertEq(configAfter.dealMinimum, 0);
        assertEq(configAfter.dealMaximum, 2000000);
        assertEq(configAfter.transferable, false);
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
        deal.configure("a", "https://social", "https://website", block.timestamp + 2 weeks, 1, 1000, 1e18);
        skip(18 days);

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));
        _configure();
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));
    }

    function test_RevertWhen_ConfigureWithWrongSender() public {
        vm.expectRevert(DealNFT.OnlySponsor.selector);
        vm.prank(staker1);
        deal.configure("a", "https://social", "https://website", block.timestamp + 2 weeks, 0, 1000, 1e18);
    }

    function test_ConfigureWithClosingTimeZero() public {
        vm.prank(sponsor);
        deal.configure("a", "https://social", "https://website", 0, 0, 1000, 1e18);
    }

    function test_RevertWhen_ConfigureWithBadClosingTime() public {
        _setup();
        vm.expectRevert(DealNFT.ClosingTimeTooSmall.selector);
        vm.prank(sponsor);
        deal.configure("a", "https://social", "https://website", block.timestamp, 0, 1000, 1e18);
    }

    function test_RevertWhen_ConfigureWithWrongRange() public {
        vm.expectRevert(DealNFT.BadStakesRange.selector);
        vm.prank(sponsor);
        deal.configure("a", "https://social", "https://website", block.timestamp + 2 weeks, 1000, 999, 1e18);
    }

    function test_RevertWhen_SetMultiplierTooSmall() public {
        vm.expectRevert(DealNFT.ZeroDetected.selector);
        vm.prank(sponsor);
        deal.configure("a", "https://social", "https://website", block.timestamp + 2 weeks, 1000, 1001, 1e17);
    }

    function test_RevertWhen_ConfigureWhenClosed() public {
        _setup();
        _configure();
        _activate();
        skip(4 weeks);
        vm.expectRevert(DealNFT.CannotConfigure.selector);
        _configure();
    }

    function test_RevertWhen_ConfigureReopen_MinimumReached() public {
        _setup();
        _configure();
        _activate();

        _stake(staker1);
        skip(17 days);

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));
        vm.expectRevert(DealNFT.MinimumReached.selector);
        _configure();
    }
}
