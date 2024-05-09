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

contract DealSetup is Test {
    DealNFT public deal;
    IERC20 public escrowToken;

    uint256 tokenId = 0;
    uint256 amount = 10;
    address sponsor;
    address staker1;
    address staker2;

    function _init() internal {
        sponsor = vm.addr(1);
        staker1 = vm.addr(2);
        staker2 = vm.addr(3);

        escrowToken = new ERC20PresetFixedSupply("escrow", "escrow", 100, address(this));
        escrowToken.transfer(address(staker1), amount);
        escrowToken.transfer(address(staker2), amount);

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
            "SurgeDealTEST",
            "SRGTEST",
            "https://test.com"
        );
    }

    function _stake(address staker) internal {
        vm.prank(staker);
        deal.stake(amount);
    }

    function _setup() internal {
        vm.prank(sponsor);
        deal.setup(address(escrowToken), 30 minutes, "https://test1.com", "https://test2.com", "https://test3.com");
    }

    function _configure() internal {
        vm.prank(sponsor);
        deal.configure("desc", block.timestamp + 2 weeks, 0, 1000);
    }

    function _activate() internal {
        vm.prank(sponsor);
        deal.activate();
    }

    function _stakerApprovals() internal {
        vm.prank(sponsor);
        deal.approveStaker(staker1, amount);
        vm.prank(sponsor);
        deal.approveStaker(staker2, amount);
    }

    function _tokenApprovals() internal {
        vm.prank(staker1);
        escrowToken.approve(address(deal), amount);
        vm.prank(staker2);
        escrowToken.approve(address(deal), amount);
    }
}
