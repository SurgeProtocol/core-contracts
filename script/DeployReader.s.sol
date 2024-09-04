// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../src/Reader.sol";
import "./Constants.sol";

contract DeployReader is Script {
    function run() external {
        Constants constants = new Constants();
        bytes32 salt = constants.salt();
        address factory = constants.factory();

        address reader = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(Reader).creationCode,
                    abi.encode()
                )
            ),
            factory
        );

        // Deploy Reader contract
        if (reader.code.length == 0) {
            vm.startBroadcast();
            new Reader{salt: salt}();
            vm.stopBroadcast();

            console.log("Reader:", reader, "(deployed)");
        } else {
            console.log("Reader:", reader, "(exists)");
        }

        console.log("\nVerification Commands:\n");
        console.log(
            "forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            reader,
            "src/Reader.sol:Reader --constructor-args"
        );
    }
}