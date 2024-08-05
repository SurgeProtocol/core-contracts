// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../src/Whitelists.sol";
import "./Constants.sol";

contract DeployWhitelist is Script {
    function run() external {
        Constants constants = new Constants();
        bytes32 salt = constants.salt();
        address factory = constants.factory();
        address sponsor = constants.sponsor();

        address whitelist = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(Whitelists).creationCode,
                    abi.encode(sponsor)
                )
            ),
            factory
        );

        // Deploy Whitelist
        if (whitelist.code.length == 0) {
            vm.startBroadcast();
            new Whitelists{salt: salt}(sponsor);
            vm.stopBroadcast();

            console.log("Whitelist:", whitelist, "(deployed)");
        } else {
            console.log("Whitelist:", whitelist, "(exists)");
        }

        console.log("\nVerification Commands:\n");
        console.log(
            "forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            whitelist,
            string.concat(
                "src/Whitelists.sol:Whitelists --constructor-args $(cast abi-encode \"constructor(address)\" ",
                Strings.toHexString(sponsor),
                ")\n"
            )
        );
    }
}