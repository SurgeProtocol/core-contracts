// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../src/Surge.sol";
import "./Constants.sol";

contract DeploySurge is Script {
    function run() external {
        Constants constants = new Constants();
        bytes32 salt = constants.salt();
        address factory = constants.factory();
        address treasury = constants.treasury(block.chainid);

        uint256 supply = 1000000000;

        address surge = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(Surge).creationCode,
                    abi.encode()
                )
            ),
            factory
        );

        // Deploy Deal
        if (surge.code.length == 0) {
            vm.startBroadcast();
            new Surge{salt: salt}(treasury, supply);
            vm.stopBroadcast();

            console.log("Surge:", surge, "(deployed)");
        } else {
            console.log("Surge:", surge, "(exists)");
        }

        console.log("\nVerification Commands:\n");
        console.log(
            "Surge: forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            surge,
            string.concat(
                "src/Surge.sol:Surge --constructor-args $(cast abi-encode \"constructor(address,uint256)\" ",
                Strings.toHexString(treasury),
                " ",
                Strings.toHexString(supply),
                ")\n"
            )
        );
    }
}