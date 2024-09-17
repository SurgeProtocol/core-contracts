// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {AccountV3TBD} from "../src/AccountV3TBD.sol";

import {Strings} from "openzeppelin/utils/Strings.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ERC20PresetFixedSupply} from "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";

import {DealSetup} from "./DealSetup.sol";

contract DealNFTTest is Test, DealSetup {
    using Strings for address;
    using Strings for uint256;

    IERC20 public notEscrowToken;

    function setUp() public {
        _init();
        _setup();
        _configure();
        _activate();

        notEscrowToken = new ERC20PresetFixedSupply("not escrow", "not escrow", 100, address(this));
    }

    function test_Stake() public {
        vm.expectEmit(address(deal));
        emit DealNFT.Stake(staker1, address(deal.getTokenBoundAccount(tokenId)), tokenId, amount);

        _stake(staker1);

        assertEq(deal.stakedAmount(tokenId), amount);
        assertEq(deal.totalStaked(), amount);
        assertEq(escrowToken.balanceOf(address(deal.getTokenBoundAccount(tokenId))), amount);
        assertEq(escrowToken.balanceOf(staker1), 0);
        assertEq(deal.ownerOf(tokenId), staker1);
        assertEq(deal.tokenURI(tokenId), string(abi.encodePacked(
            "https://test.com/chain/",
            block.chainid.toString(),
            "/deal/",
            address(deal).toHexString(),
            "/token/0"
        )));
    }

    function test_Unstake() public {
        _stake(staker1);

        vm.expectEmit(address(deal));
        emit DealNFT.Unstake(staker1, address(deal.getTokenBoundAccount(tokenId)), tokenId, amount);

        vm.prank(staker1);
        deal.unstake(tokenId);

        assertEq(deal.stakedAmount(tokenId), 0);
        assertEq(escrowToken.balanceOf(staker1), 950000);
        assertEq(escrowToken.balanceOf(address(deal.getTokenBoundAccount(tokenId))), 0);
        assertEq(escrowToken.balanceOf(treasury), 25000);
        assertEq(deal.totalStaked(), 0);
    }

    function test_Claim() public {
        _depositDeliveryTokens();
        _stake(staker1);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));

        skip(15 days);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Claiming));

        vm.expectEmit(address(deal));
        emit DealNFT.Claim(staker1, tokenId, amount);

        vm.prank(sponsor);
        deal.claim();

        assertEq(deal.stakedAmount(tokenId), amount);
        assertEq(escrowToken.balanceOf(sponsor), 970000);
        assertEq(escrowToken.balanceOf(treasury), 30000);
        assertEq(escrowToken.balanceOf(address(deal.getTokenBoundAccount(tokenId))), 0);
        assertEq(deal.totalStaked(), amount);
        assertEq(deal.totalClaimed(), amount);
    }

    function test_TransferOtherTokens() public {
        assertEq(deal.allowToken(address(notEscrowToken)), true);

        _stake(staker1);
        AccountV3TBD tba = deal.getTokenBoundAccount(tokenId);
        notEscrowToken.transfer(address(tba), 100);
        assertEq(notEscrowToken.balanceOf(address(tba)), 100);
        assertEq(notEscrowToken.balanceOf(sponsor), 0);

        bytes memory erc20TransferCall =
            abi.encodeWithSignature("transfer(address,uint256)", sponsor, 100);
        vm.prank(staker1);
        tba.execute(payable(address(notEscrowToken)), 0, erc20TransferCall, 0);
        assertEq(notEscrowToken.balanceOf(address(tba)), 0);
        assertEq(notEscrowToken.balanceOf(sponsor), 100);
    }

}
