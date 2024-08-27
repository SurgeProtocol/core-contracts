// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../src/StakingRelayer.sol";
import "./Constants.sol";

contract DeployStakingRelayer is Script {
    function run() external {
        Constants constants = new Constants();
        bytes32 salt = constants.salt();
        address factory = constants.factory();
        address owner = constants.treasury(block.chainid);

        address relayer = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(StakingRelayer).creationCode,
                    abi.encode()
                )
            ),
            factory
        );

        // Deploy StakingRelayer
        if (relayer.code.length == 0) {
            vm.startBroadcast();
            new StakingRelayer{salt: salt}(owner);
            vm.stopBroadcast();

            console.log("StakingRelayer:", relayer, "(deployed)");
        } else {
            console.log("StakingRelayer:", relayer, "(exists)");
        }

        console.log("\nVerification Commands:\n");
        console.log(
            "forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            relayer,
            string.concat(
                "src/StakingRelayer.sol:StakingRelayer --constructor-args $(cast abi-encode \"constructor(address)\" ",
                Strings.toHexString(owner),
                ")\n"
            )
        );
    }
}
