// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../src/DealFactory.sol";

contract DeployDealFactory is Script {
    function run() external {
        bytes32 salt = 0x6551655165516551655165516551655165516551655165516551655165516551;
        address factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

        address registry = 0x000000006551c19487814612e58FE06813775758;
        // TODO: change to a cross chain standard address
        address implementation = 0x83Bd10AE8E626EE9977Eaf222487fFCE60279c30;
        // TODO: change to a multisig
        address treasury = 0x6049176a7507cC93bafaaC786f4Aa5Fb37707207;

        string memory baseURI = "https://api.surge.rip";

        address dealFactory = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(DealFactory).creationCode,
                    abi.encode(
                        registry,
                        implementation,
                        treasury,
                        baseURI
                    )
                )
            ),
            factory
        );

        // Deploy Deal
        if (dealFactory.code.length == 0) {
            vm.startBroadcast();
            new DealFactory{salt: salt}(
                registry,
                implementation,
                treasury,
                baseURI
            );
            vm.stopBroadcast();

            console.log("DealFactory:", dealFactory, "(deployed)");
        } else {
            console.log("DealNFT:", dealFactory, "(exists)");
        }

        console.log("\nVerification Commands:\n");
        console.log(
            "DealFactory: forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            dealFactory,
            string.concat(
                "src/DealNFT.sol:DealNFT --constructor-args $(cast abi-encode \"constructor(address,address,address,string)\" ",
                Strings.toHexString(registry),
                " ",
                Strings.toHexString(implementation),
                " ",
                Strings.toHexString(treasury),
                " ",
                baseURI,
                ")\n"
            )
        );
    }
}