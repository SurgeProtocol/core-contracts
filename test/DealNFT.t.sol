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

contract DealTest is Test {
    Multicall3 forwarder;
    ERC6551Registry public registry;
    AccountGuardian public guardian;
    
    DealNFT public deal;
    AccountV3TBD public implementation;
    IERC20 public escrowToken;
    IERC20 public notEscrowToken;

    uint256 tokenId = 0;
    uint256 amount = 10;
    address staker;
    address sponsor;

    function setUp() public {
        staker = vm.addr(1);
        sponsor = vm.addr(2);
        
        escrowToken = new ERC20PresetFixedSupply("escrow", "escrow", 100, address(this));
        notEscrowToken = new ERC20PresetFixedSupply("not escrow", "not escrow", 100, address(this));
        registry = new ERC6551Registry();
        forwarder = new Multicall3();
        guardian = new AccountGuardian(address(this));

        escrowToken.transfer(address(staker), amount);

        implementation = new AccountV3TBD(
            address(1), address(forwarder), address(registry), address(guardian)
        );

        vm.expectEmit(true, false, false, true);
        emit DealNFT.Deal(sponsor, address(escrowToken));
    
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


        assertEq(uint256(deal.state()), uint256(DealNFT.State.Configuration));
        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));

        vm.prank(sponsor);
        deal.approveStaker(staker, amount);

        vm.prank(staker);
        escrowToken.approve(address(deal), amount);
    }

    function test_Config() public view {
        // constructor params
        assertEq(deal.sponsor(), sponsor);
        assertEq(deal.baseURI(), string(abi.encodePacked("https://test.com/deal/", address(deal), "/token/")));
        assertEq(deal.web(), "https://test.com");
        assertEq(deal.twitter(), "https://x.com/@example");
        assertEq(address(deal.escrowToken()), address(escrowToken));

        // configuration params
        assertEq(deal.description(), "lorem ipsum");
        assertEq(deal.closingTime(), block.timestamp + 2 weeks);
        assertEq(deal.transferrable(), false);
        assertEq(deal.dealMinimum(), 0);
        assertEq(deal.dealMaximum(), 1000);

        // defaults
        assertEq(deal.nextId(), 0);
        assertEq(deal.totalStaked(), 0);
        assertEq(deal.totalClaimed(), 0);
        assertEq(deal.allowToken(address(escrowToken)), false);
        assertEq(deal.allowToken(address(notEscrowToken)), true);
    }

    function test_Stake() public {
        vm.expectEmit(address(deal));
        emit DealNFT.Stake(staker, deal.getTokenBoundAccount(tokenId), tokenId, amount);

        stake();

        assertEq(deal.stakedAmount(tokenId), amount);
        assertEq(deal.totalStaked(), amount);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(tokenId)), amount);
        assertEq(escrowToken.balanceOf(staker), 0);
        assertEq(deal.ownerOf(tokenId), staker);
        assertEq(deal.tokenURI(tokenId), string(abi.encodePacked("https://test.com/deal/", address(deal), "/token/0")));
    }

    function test_Unstake() public {
        stake();

        vm.expectEmit(address(deal));
        emit DealNFT.Unstake(staker, deal.getTokenBoundAccount(tokenId), tokenId, amount);

        vm.prank(staker);
        deal.unstake(tokenId);

        assertEq(deal.stakedAmount(tokenId), 0);
        assertEq(escrowToken.balanceOf(staker), amount);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(tokenId)), 0);
        assertEq(deal.totalStaked(), 0);
    }

    function test_Claim() public {
        stake();
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Active));

        skip(15 days);
        assertEq(uint256(deal.state()), uint256(DealNFT.State.Closing));

        vm.expectEmit(address(deal));
        emit DealNFT.Claim(sponsor, staker, tokenId, amount);

        vm.prank(sponsor);
        deal.claim();

        assertEq(deal.stakedAmount(tokenId), amount);
        assertEq(escrowToken.balanceOf(sponsor), amount);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(tokenId)), 0);
        assertEq(deal.totalStaked(), amount);
        assertEq(deal.totalClaimed(), amount);
    }

    function test_TransferOtherTokens() public {
        stake();
        address tba = deal.getTokenBoundAccount(tokenId);
        notEscrowToken.transfer(address(tba), amount);
        assertEq(notEscrowToken.balanceOf(tba), amount);
        assertEq(notEscrowToken.balanceOf(sponsor), 0);

        AccountV3TBD account = AccountV3TBD(payable(tba));
        bytes memory erc20TransferCall =
            abi.encodeWithSignature("transfer(address,uint256)", sponsor, amount);
        vm.prank(staker);
        account.execute(payable(address(notEscrowToken)), 0, erc20TransferCall, 0);
        assertEq(notEscrowToken.balanceOf(tba), 0);
        assertEq(notEscrowToken.balanceOf(sponsor), amount);
    }

    function stake() internal {
        vm.prank(staker);
        deal.stake(amount);
    }
}
