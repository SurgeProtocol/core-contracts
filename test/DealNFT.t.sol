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

        implementation = new AccountV3TBD(
            address(1), address(forwarder), address(registry), address(guardian)
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

        assertEq(uint256(deal.state()), 0); // Configuring
        vm.prank(sponsor);
        deal.configure("lorem ipsum", block.timestamp + 2 weeks, 0, 1000);
        vm.prank(sponsor);
        deal.approveStaker(staker, amount);

        assertEq(uint256(deal.state()), 1); // Active
        escrowToken.transfer(address(staker), amount);
    }

    function test_Config() public view {
        // constructor params
        assertEq(deal.sponsor(), sponsor);
        assertEq(deal.tokenURI(0), "https://test.com/hello.png");
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
        stake();

        assertEq(deal.stakedAmount(tokenId), amount);
        assertEq(deal.totalStaked(), amount);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(tokenId)), amount);
        assertEq(escrowToken.balanceOf(staker), 0);
        assertEq(deal.ownerOf(tokenId), staker);
    }

    function test_Unstake() public {
        stake();

        vm.prank(staker);
        deal.unstake(tokenId);

        assertEq(deal.stakedAmount(tokenId), 0);
        assertEq(escrowToken.balanceOf(staker), amount);
        assertEq(escrowToken.balanceOf(deal.getTokenBoundAccount(tokenId)), 0);
        assertEq(deal.totalStaked(), 0);
    }

    function test_Claim() public {
        stake();
        assertEq(uint256(deal.state()), 1); // Active

        skip(15 days);
        assertEq(uint256(deal.state()), 2); // Closing

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
        vm.startPrank(staker);
        escrowToken.approve(address(deal), amount);
        deal.stake(amount);
        vm.stopPrank();
    }
}
