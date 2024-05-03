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

contract DealNFTClaim is Test {
    Multicall3 forwarder;
    ERC6551Registry public registry;
    AccountGuardian public guardian;

    DealNFT public deal;
    AccountV3TBD public implementation;
    IERC20 public escrowToken;

    uint256 tokenId = 0;
    uint256 amount = 10;
    address sponsor;
    address staker1;
    address staker2;

    function setUp() public {
        sponsor = vm.addr(1);
        staker1 = vm.addr(2);
        staker2 = vm.addr(3);

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
            address(escrowToken)
        );
        escrowToken.transfer(address(staker1), amount);
        escrowToken.transfer(address(staker2), amount);
    }

    function test_Claim() public {
        _configure();
        _stake(staker1);
        _stake(staker2);
        assertEq(deal.totalStaked(), amount * 2);

        skip(15 days);
        assertEq(uint256(deal.state()), 2); // Closing

        vm.prank(sponsor);
        deal.claim();

        assertEq(deal.stakedAmount(0), amount);
        assertEq(deal.stakedAmount(1), amount);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(0)), 0);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(1)), 0);
        assertEq(escrowToken.balanceOf(sponsor), amount * 2);
        assertEq(deal.totalStaked(), amount * 2);
        assertEq(deal.totalClaimed(), amount * 2);
    }

    function testFail_ClaimWithWrongSponsor() public {
        _setup();
        vm.prank(staker1);
        deal.claim();
    }

    function testFail_ClaimBeforeClosing() public {
        _configure();
        _stake(staker1);
        _stake(staker2);
        vm.prank(sponsor);
        deal.claim();
    }

    function testFail_ClaimAfterClosing() public {
        _configure();
        _stake(staker1);
        _stake(staker2);
        skip(22 days);
        vm.prank(sponsor);
        deal.claim();
    }

    function testFail_ClaimAfterCanceled() public {
        _setup();

        vm.startPrank(sponsor);
        deal.cancel();

        deal.claim();
        vm.stopPrank();
    }

    function testFail_ClaimOutOfBounds() public {
        _setup();

        vm.startPrank(sponsor);
        deal.claim();
        deal.claimNext();
        vm.stopPrank();
    }

    function testFail_ClaimMinimumNotReached() public {
        vm.prank(sponsor);
        deal.configure(
            "lorem ipsum",
            block.timestamp + 2 weeks,
            true,
            100,
            1000
        );
        _stake(staker1);
        _stake(staker2);
        skip(15 days);

        vm.prank(sponsor);
        deal.claim();
    }

    // ***** Internals *****
    function _setup() internal {
        _configure();
        _stake(staker1);
        _stake(staker2);
        skip(15 days);
    }

    function _configure() internal {
        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, true, 0, 1000);
    }

    function _stake(address user) internal {
        vm.startPrank(user);
        escrowToken.approve(address(deal), amount);
        deal.stake(amount);
        vm.stopPrank();
    }
}
