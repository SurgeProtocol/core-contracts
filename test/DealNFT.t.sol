// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {AccountV3Escrow} from "../src/AccountV3Escrow.sol";

import "multicall-authenticated/Multicall3.sol";
import "erc6551/ERC6551Registry.sol";
import "tokenbound/src/AccountGuardian.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ERC20PresetFixedSupply} from "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract DealTest is Test {
    Multicall3 forwarder;
    ERC6551Registry public registry;
    AccountGuardian public guardian;
    
    DealNFT public deal;
    AccountV3Escrow public implementation;
    IERC20 public escrowToken;

    uint256 tokenId = 0;
    uint256 amount = 10;
    address staker;
    address sponsor;

    function setUp() public {
        staker = vm.addr(1);
        sponsor = vm.addr(2);
        
        escrowToken = new ERC20PresetFixedSupply("escrow", "escrow", 100, address(this));
        registry = new ERC6551Registry();
        forwarder = new Multicall3();
        guardian = new AccountGuardian(address(this));

        implementation = new AccountV3Escrow(
            address(1), address(forwarder), address(registry), address(guardian)
        );

        deal = new DealNFT(
            "https://test.com",
            address(escrowToken),
            block.timestamp + 2 days,
            address(registry),
            payable(address(implementation)),
            sponsor
        );

        escrowToken.transfer(address(staker), amount);
    }

    function test_Config() public view {
        assertEq(deal.sponsorAddress(), sponsor);
        assertEq(deal.tokenURI(0), "https://test.com");
        assertEq(address(deal.escrowToken()), address(escrowToken));
        assertEq(deal.closingTimestamp(), block.timestamp + 2 days);
        assertEq(address(deal.registry()), address(registry));
        assertEq(address(deal.implementation()), address(implementation));
    }

    function test_Stake() public {
        stake();

        assertEq(deal.amountOf(tokenId), amount);
        assertEq(deal.totalDeposited(), amount);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(tokenId)), amount);
        assertEq(escrowToken.balanceOf(staker), 0);
        assertEq(deal.ownerOf(tokenId), staker);
    }

    function test_Unstake() public {
        stake();

        vm.prank(staker);
        deal.unstake(tokenId, amount);        

        assertEq(deal.amountOf(tokenId), 0);
        assertEq(escrowToken.balanceOf(staker), amount);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(tokenId)), 0);
        assertEq(deal.totalDeposited(), 0);
    }

    function test_Close() public {
        stake();
        skip(3 days);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;    
        vm.prank(sponsor);
        deal.close(tokenIds);

        assertEq(deal.amountOf(tokenId), 0);
        assertEq(escrowToken.balanceOf(sponsor), amount);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(tokenId)), 0);
        assertEq(deal.totalDeposited(), 0);
    }

    function stake() internal {
        vm.startPrank(staker);
        escrowToken.approve(address(deal), amount);
        deal.stake(amount);
        vm.stopPrank();
    }

}
