// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";
import {Whitelists} from "../src/Whitelists.sol";

contract DealNFTWhitelistsTest is Test, DealSetup {
    Whitelists whitelist;

    function setUp() public {
        _init();        
        _setup();
        _configure();
        _activate();

        whitelist = new Whitelists(address(sponsor));
    }

    function test_SetWhitelists() public {
        assertEq(address(deal.stakersWhitelist()), address(0));
        assertEq(address(deal.claimsWhitelist()), address(0));

        vm.prank(sponsor);
        deal.setStakersWhitelist(address(whitelist));
        vm.prank(sponsor);
        deal.setClaimsWhitelist(address(whitelist));

        assertEq(address(deal.stakersWhitelist()), address(whitelist));
        assertEq(address(deal.claimsWhitelist()), address(whitelist));
    }

    function test_RevertWhen_SetWhitelistsWithWrongSender() public {
        vm.prank(staker1);
        vm.expectRevert("only sponsor");
        deal.setStakersWhitelist(address(whitelist));
        vm.expectRevert("only sponsor");
        deal.setClaimsWhitelist(address(whitelist));
    }

    function test_StakingWithApproval() public {
        vm.prank(sponsor);
        deal.setStakersWhitelist(address(whitelist));

        vm.prank(sponsor);
        whitelist.approveStaker(staker1, amount);

        _stake(staker1);
    }

    function test_RevertWhen_StakingWithoutApproval() public {
        vm.prank(sponsor);
        deal.setStakersWhitelist(address(whitelist));

        vm.expectRevert("whitelist error");
        _stake(staker1);
    }

    function test_SkipsUnqualifiedClaims() public {
        _transferRewards();
        vm.prank(sponsor);
        deal.setClaimsWhitelist(address(whitelist));

        _stake(staker1);
        _stake(staker2);

        assertEq(deal.totalStaked(), 0);
        vm.prank(sponsor);
        whitelist.approveBuyer(staker1, true);
        assertEq(deal.totalStaked(), amount);

        skip(15 days);
        vm.prank(sponsor);
        deal.claim();

        assertEq(escrowToken.balanceOf(sponsor), 970000);
    }
}
