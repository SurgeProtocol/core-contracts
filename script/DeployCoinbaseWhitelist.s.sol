// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../src/CoinbaseWhitelists.sol";
import "./Constants.sol";

contract DeployCoinbaseWhitelist is Script {
    function run() external {
        Constants constants = new Constants();
        bytes32 salt = constants.salt();
        address factory = constants.factory();
        address sponsor = constants.sponsor();

        address coinbaseWhitelist = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(CoinbaseWhitelists).creationCode,
                    abi.encode(sponsor)
                )
            ),
            factory
        );

        // Deploy CoinbaseWhitelist
        if (coinbaseWhitelist.code.length == 0) {
            vm.startBroadcast();
            new CoinbaseWhitelists{salt: salt}(sponsor);
            vm.stopBroadcast();

            console.log("CoinbaseWhitelist:", coinbaseWhitelist, "(deployed)");
        } else {
            console.log("CoinbaseWhitelist:", coinbaseWhitelist, "(exists)");
        }

        console.log("\nVerification Commands:\n");
        console.log(
            "forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            coinbaseWhitelist,
            string.concat(
                "src/CoinbaseWhitelists.sol:CoinbaseWhitelists --constructor-args $(cast abi-encode \"constructor(address)\" ",
                Strings.toHexString(sponsor),
                ")\n"
            )
        );
    }
}