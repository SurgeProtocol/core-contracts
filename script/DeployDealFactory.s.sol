// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

import "../src/DealFactory.sol";
import "./Constants.sol";

contract DeployDealFactory is Script {
    function run() external {
        Constants constants = new Constants();
        bytes32 salt = constants.salt();
        address factory = constants.factory();
        address registry = constants.registry();
        address implementation = constants.implementation(block.chainid);
        address treasury = constants.treasury(block.chainid);
        address owner = treasury;

        string memory nftURI = string.concat(
            constants.nftURI(),
            "/chain/",
            Strings.toString(block.chainid),
            "/deal/"
        );

        address dealFactory = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(DealFactory).creationCode,
                    abi.encode(
                        owner,
                        treasury,
                        registry,
                        implementation,
                        nftURI
                    )
                )
            ),
            factory
        );

        // Deploy Deal
        if (dealFactory.code.length == 0) {
            vm.startBroadcast();
            new DealFactory{salt: salt}(
                owner,
                treasury,
                registry,
                implementation,
                nftURI
            );
            vm.stopBroadcast();

            console.log("DealFactory:", dealFactory, "(deployed)");
        } else {
            console.log("DealFactory:", dealFactory, "(exists)");
        }

        console.log("\nVerification Commands:\n");
        console.log(
            "DealFactory: forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            dealFactory,
            string.concat(
                "src/DealFactory.sol:DealFactory --constructor-args $(cast abi-encode \"constructor(address,address,address,address,string)\" ",
                Strings.toHexString(owner),
                " ",
                Strings.toHexString(treasury),
                " ",
                Strings.toHexString(registry),
                " ",
                Strings.toHexString(implementation),
                " ",
                nftURI,
                ")\n"
            )
        );
    }
}