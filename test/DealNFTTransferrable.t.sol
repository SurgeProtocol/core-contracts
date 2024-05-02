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

contract DealNFTTransferrable is Test {
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
    }

    function test_TransferNFT() public {
        _configure(true);
        _stake(staker1);
        assertEq(deal.ownerOf(tokenId), staker1);

        vm.prank(staker1);
        deal.transferFrom(staker1, staker2, tokenId);
        assertEq(deal.ownerOf(tokenId), staker2);

        vm.prank(staker2);
        deal.unstake(tokenId);
        assertEq(escrowToken.balanceOf(staker2), amount);
    }

    function testFail_TransferNFT() public {
        _configure(false);
        _stake(staker1);
        assertEq(deal.ownerOf(tokenId), staker1);

        vm.prank(staker1);
        deal.transferFrom(staker1, staker2, tokenId);
    }

    // ***** Internals *****
    function _configure(bool tranferrable) internal {
        vm.prank(sponsor);
        deal.configure(
            "lorem ipsum",
            block.timestamp + 2 weeks,
            tranferrable,
            0,
            1000
        );
    }

    function _stake(address user) internal {
        vm.startPrank(user);
        escrowToken.approve(address(deal), amount);
        deal.stake(amount);
        vm.stopPrank();
    }
}
