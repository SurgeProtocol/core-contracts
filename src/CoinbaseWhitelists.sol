// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Whitelists} from "./Whitelists.sol";
import {IWhitelist} from "./interfaces/IWhitelist.sol";
import {AttestationVerifier} from "verifications/libraries/AttestationVerifier.sol";
import {Attestation, EAS} from "eas-contracts/EAS.sol";

contract CoinbaseWhitelists is Whitelists {
    mapping(address staker => bytes32) public stakerUID;

    // base chain EAS contract address
    address private constant _EAS = 0x4200000000000000000000000000000000000021;
    bytes32 private constant _SCHEMA = 0xF8B05C79F090979BF4A80270ABA232DFF11A10D9CA55C4F88DE95317970F0DE9;

    constructor(address sponsor_) Whitelists(sponsor_) {}

    function addAttestation(address staker_, bytes32 uid_) external {
        verify(staker_, uid_);
        stakerUID[staker_] = uid_;
    }

    function canStake(address staker_, uint256 amount_) public view override returns (bool) {
        bytes32 uid = stakerUID[staker_];
        verify(staker_, uid);
        return super.canStake(staker_, amount_);
    }

    function verify(address staker_, bytes32 uid_) private view {
        Attestation memory attestation = EAS(_EAS).getAttestation(uid_);
        AttestationVerifier.verifyAttestation(attestation, staker_, _SCHEMA);
        // this will revert if the attestation is invalid
    }
}
