// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "./Constants.sol";
import "../src/WhitelistFactory.sol";

contract DeployWhitelistFactory is Script {
    function run() external {
        Constants constants = new Constants();
        bytes32 salt = constants.salt();
        address factory = constants.factory();

        address whitelistFactory = Create2.computeAddress(
            salt,
            keccak256(abi.encodePacked(type(WhitelistFactory).creationCode)),
            factory
        );

        // Deploy Whitelist
        if (whitelistFactory.code.length == 0) {
            vm.startBroadcast();
            new WhitelistFactory{salt: salt}();
            vm.stopBroadcast();

            console.log("WhitelistFactory:", whitelistFactory, "(deployed)");
        } else {
            console.log("WhitelistFactory:", whitelistFactory, "(exists)");
        }

        console.log("\nVerification Commands:\n");
        console.log(
            "forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            whitelistFactory,
            "src/WhitelistFactory.sol:WhitelistFactory \n"
        );
    }
}
