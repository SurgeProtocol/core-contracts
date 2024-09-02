// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {Whitelists} from "./Whitelists.sol";
import {IWhitelist} from "./interfaces/IWhitelist.sol";
import {AttestationVerifier} from "verifications/libraries/AttestationVerifier.sol";
import {Attestation, EAS} from "eas-contracts/EAS.sol";

contract CoinbaseWhitelists is Whitelists {
    mapping(address staker => bytes32) public stakerUID;

    // base chain EAS contract address
    address private constant _EAS = 0x4200000000000000000000000000000000000021;

    constructor(address sponsor_) Whitelists(sponsor_) {}

    function addAttestation(address staker_, bytes32 uid_) external {
        require(stakesApprovals[staker_] > 0, "staker not approved");
        verify(uid_);
        stakerUID[staker_] = uid_;
    }

    function canStake(address staker_, uint256 amount_) public view override returns (bool) {
        verify(stakerUID[staker_]);
        return super.canStake(staker_, amount_);
    }

    function verify(bytes32 uid_) private view {
        Attestation memory attestation = EAS(_EAS).getAttestation(uid_);
        AttestationVerifier.verifyAttestation(attestation);
        // this will revert if the attestation is invalid
    }
}
