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

contract DealNFTCancel is Test {
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
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);
        vm.prank(sponsor);
        deal.approveStaker(staker, amount);

        escrowToken.transfer(address(staker), amount);
    }

    function test_Cancel() public {
        _stake();

        vm.expectEmit(address(deal));
        emit DealNFT.Cancel(sponsor);

        vm.prank(sponsor);
        deal.cancel();
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Canceled));
    }

    function test_RevertWhen_CancelWrongSponsor() public {
        _stake();

        vm.expectRevert("not the sponsor");
        vm.prank(staker);
        deal.cancel();
    }

    function test_RevertWhen_CancelAfterActivated() public {
        _stake();
        skip(15 days);
        assertEq(uint(deal.state()), uint256(DealNFT.State.Closing));

        vm.expectRevert("cannot be canceled");
        vm.prank(sponsor);
        deal.cancel();
    }

    // ***** Internals *****
    function _stake() internal {
        vm.startPrank(staker);
        escrowToken.approve(address(deal), amount);
        deal.stake(amount);
        vm.stopPrank();
    }
}
