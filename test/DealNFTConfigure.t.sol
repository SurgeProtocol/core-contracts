// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {AccountV3TBD} from "../src/AccountV3TBD.sol";

import "multicall-authenticated/Multicall3.sol";
import "erc6551/ERC6551Registry.sol";
import "tokenbound/src/AccountGuardian.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ERC20PresetFixedSupply} from "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract DealNFTConfigure is Test {
    Multicall3 forwarder;
    ERC6551Registry public registry;
    AccountGuardian public guardian;

    DealNFT public deal;
    AccountV3TBD public implementation;
    IERC20 public escrowToken;

    uint256 tokenId = 0;
    uint256 amount = 10;
    address staker;
    address sponsor;

    function setUp() public {
        staker = vm.addr(1);
        sponsor = vm.addr(2);

        escrowToken = new ERC20PresetFixedSupply(
            "escrow",
            "escrow",
            100,
            address(this)
        );
        registry = new ERC6551Registry();
        forwarder = new Multicall3();
        guardian = new AccountGuardian(address(this));

        implementation = new AccountV3TBD(
            address(1),
            address(forwarder),
            address(registry),
            address(guardian)
        );

        deal = new DealNFT(
            address(registry),
            payable(address(implementation)),
            sponsor,
            "https://test.com",
            "https://test.com",
            "https://x.com/@example",
            address(escrowToken),
            1 weeks
        );

        vm.prank(sponsor);
        deal.approveStaker(staker, amount);

        escrowToken.transfer(address(staker), amount);
    }

    function test_Configure() public {
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Configuration));

        vm.expectEmit(address(deal));
        emit DealNFT.Configure(sponsor, "lorem ipsum", block.timestamp + 2 weeks, 0, 1000);

        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));
    }

    function test_ReconfigureWhenActive() public {
        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);

        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));
    }

    function test_ReconfigureMinimumNotReached() public {
        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 1, 1000);

        skip(18 days);

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Closing));

        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 1, 1000);

        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));
    }

    function test_RevertWhen_ConfigureWithWrongSender() public {
        vm.expectRevert("not the sponsor");
        vm.prank(staker);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);
    }

    function test_RevertWhen_ConfigureWithClosingTimeZero() public {
        vm.expectRevert("invalid closing time");
        vm.prank(sponsor);
        deal.configure("lorem ipsum", 0, 0, 1000);
    }

    function test_RevertWhen_ConfigureWithClosingTimeMinimum() public {
        vm.expectRevert("invalid closing time");
        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 1 weeks, 0, 1000);
    }

    function test_RevertWhen_ConfigureWithWrongRange() public {
        vm.expectRevert("wrong deal range");
        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 1000, 1000);
    }

    function test_RevertWhen_ConfigureWhenClosed() public {
        vm.startPrank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 8 days, 0, 1000);
        skip(16 days);
        vm.expectRevert("cannot configure anymore");
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);
        vm.stopPrank();
    }

    function test_RevertWhen_ConfigureReopen_MinimumReached() public {
        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 8 days, 1, 1000);

        vm.startPrank(staker);
        escrowToken.approve(address(deal), amount);
        deal.stake(amount);
        vm.stopPrank();

        skip(13 days);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Closing));
        vm.expectRevert("minimum stake reached");
        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);
    }
}
