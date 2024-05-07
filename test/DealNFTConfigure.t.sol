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
            "https://test.com/hello.png",
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
        uint256 _state = uint256(deal.state());
        assertEq(_state, 0); // Configuring

        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);

        _state = uint256(deal.state());
        assertEq(_state, 1); // Active
    }

    function testFail_ConfigureWithClosingTimeZero() public {
        vm.prank(sponsor);
        deal.configure("lorem ipsum", 0, 0, 1000);
    }

    function testFail_ConfigureWithClosingTimeMinimum() public {
        vm.prank(sponsor);
        uint256 closingTime = (block.timestamp + 1 weeks);
        deal.configure("lorem ipsum", closingTime, 0, 1000);
    }

    function testFail_ConfigureWithWrongRange() public {
        vm.prank(sponsor);
        deal.configure(
            "lorem ipsum",
            block.timestamp + 2 weeks,
            1000,
            1000
        );
    }

    function testFail_ConfigureWithWrongSender() public {
        vm.prank(staker);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);
    }

    function testFail_ConfigureWhenClosed() public {
        vm.startPrank(sponsor);
        deal.configure(
            "lorem ipsum",
            block.timestamp + 1 weeks + 1,
            0,
            1000
        );
        skip(15 days);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);
        vm.stopPrank();
    }

    function testFail_ConfigureReopen() public {
        vm.startPrank(sponsor);
        deal.configure(
            "lorem ipsum",
            block.timestamp + 1 weeks + 1,
            1,
            1000
        );

        vm.startPrank(staker);
        escrowToken.approve(address(deal), amount);
        deal.stake(amount);
        vm.stopPrank();

        skip(10 days);
        uint256 _state = uint256(deal.state());
        assertEq(_state, 2); // Closing
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);
        vm.stopPrank();
    }
}
