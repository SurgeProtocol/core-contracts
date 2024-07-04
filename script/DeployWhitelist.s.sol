// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../src/Whitelists.sol";

contract DeployWhitelist is Script {
    function run() external {
        bytes32 salt = 0x6551655165516551655165516551655165516551655165516551655165516553;
        address factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        
        address sponsor = 0x68b2a7B9ca1D8C87A170e9Bb2e120cFd09Ef144F;

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