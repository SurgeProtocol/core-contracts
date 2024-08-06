// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../src/GoSurge.sol";
import "./Constants.sol";

contract DeployGoSurge is Script {
    function run() external {
        Constants constants = new Constants();
        bytes32 salt = constants.salt();
        address factory = constants.factory();

        address gosurge = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(GoSurge).creationCode,
                    abi.encode()
                )
            ),
            factory
        );

        // Deploy GoSurge
        if (gosurge.code.length == 0) {
            vm.startBroadcast();
            new GoSurge{salt: salt}();
            vm.stopBroadcast();

            console.log("GoSurge:", gosurge, "(deployed)");
        } else {
            console.log("GoSurge:", gosurge, "(exists)");
        }

        console.log("\nVerification Commands:\n");
        console.log(
            "GoSurge: forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            gosurge,
            "src/GoSurge.sol:GoSurge --constructor-args"
        );
    }
}