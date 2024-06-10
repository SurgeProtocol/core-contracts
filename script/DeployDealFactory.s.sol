// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../src/DealFactory.sol";

contract DeployDealFactory is Script {
    function run() external {
        bytes32 salt = 0x6551655165516551655165516551655165516551655165516551655165516551;
        address factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        address registry = 0x000000006551c19487814612e58FE06813775758;

        // arbitrum
        address implementation = 0x8A6bDD9B33D21D96112cc67B52C91719178Cc704;
        address treasury = 0x837bb49403346a307C449Fe831cCA5C1992C57f5;

        // base
        // address implementation = 0x6AE9d37F3c4240c9288059B743652b67cE20FcDD;
        // address treasury = 0x39110eEfD8542b3308817a27EbD3509386D37754;

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
            console.log("DealFactory:", dealFactory, "(exists)");
        }

        console.log("\nVerification Commands:\n");
        console.log(
            "DealFactory: forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            dealFactory,
            string.concat(
                "src/DealFactory.sol:DealFactory --constructor-args $(cast abi-encode \"constructor(address,address,address,string)\" ",
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