// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {DealSetup} from "./DealSetup.sol";
import {CoinbaseWhitelists} from "../src/CoinbaseWhitelists.sol";
import {AttestationNotFound} from "verifications/libraries/AttestationVerifier.sol";

// Only runs on Base
// forge test --match-contract DealNFTCoinbaseWhitelistsTest --fork-url https://mainnet.base.org

contract DealNFTCoinbaseWhitelistsTest is Test, DealSetup {
    CoinbaseWhitelists whitelist;

    address attestation_recipient = address(0xc34A0C8FDaA8dE323A50fF893d7Ca6028c477ae5);
    bytes32 attestation_uid = 0x018A59A87F02771C0DA2C77B58E3F587D3F52760AD0F0ED43827BC45737D3FB3;

    function setUp() public {
        _init();
        _setup();
        _configure();
        _activate();

        whitelist = new CoinbaseWhitelists(address(sponsor));

        escrowToken.transfer(address(attestation_recipient), amount);
        vm.prank(attestation_recipient);
        escrowToken.approve(address(deal), amount);
    }

    function test_CoinbaseWhitelists() public {
        if(block.chainid != 8453) return;

        vm.prank(sponsor);
        deal.setStakersWhitelist(address(whitelist));
        
        vm.prank(sponsor);
        whitelist.approveStaker(attestation_recipient, amount);

        vm.prank(attestation_recipient);
        whitelist.addAttestation(attestation_recipient, attestation_uid);

        vm.prank(attestation_recipient);
        deal.stake(attestation_recipient, amount);
    }

    function test_RevertsWhen_BadAttestation() public {
        if(block.chainid != 8453) return;

        vm.prank(sponsor);
        deal.setStakersWhitelist(address(whitelist));

        vm.expectRevert(AttestationNotFound.selector);
        bytes32 bad_attestation_uid = 0x018A59A87F02771C0DA2C77B58E3F587D3F52760AD0F0ED43827BC45737D3FB4;
        vm.prank(attestation_recipient);
        whitelist.addAttestation(attestation_recipient, bad_attestation_uid);

        vm.expectRevert(AttestationNotFound.selector);
        vm.prank(attestation_recipient);
        deal.stake(attestation_recipient, amount);
    }

}
