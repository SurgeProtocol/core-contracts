// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../src/DealNFT.sol";
import "./Constants.sol";

contract DeployDealNFT is Script {
    function run() external {
        Constants constants = new Constants();
        bytes32 salt = constants.salt();
        address factory = constants.factory();
        address registry = constants.registry();
        address implementation = constants.implementation(block.chainid);
        address treasury = constants.treasury(block.chainid);
        address sponsor = constants.sponsor();
        string memory baseURI = constants.baseURI();

        string memory name = "Surge Test";
        string memory symbol = "SRGTST";        

        address deal = Create2.computeAddress(
            salt,
            keccak256(
                abi.encodePacked(
                    type(DealNFT).creationCode,
                    abi.encode(
                        registry,
                        implementation,
                        sponsor,
                        treasury,
                        name,
                        symbol,
                        baseURI
                    )
                )
            ),
            factory
        );

        // Deploy Deal
        if (deal.code.length == 0) {
            vm.startBroadcast();
            new DealNFT{salt: salt}(
                registry,
                implementation,
                sponsor,
                treasury,
                name,
                symbol,
                baseURI
            );
            vm.stopBroadcast();

            console.log("DealNFT:", deal, "(deployed)");
        } else {
            console.log("DealNFT:", deal, "(exists)");
        }

        console.log("\nVerification Commands:\n");
        console.log(
            "DealNFT: forge verify-contract --num-of-optimizations 200 --chain-id",
            block.chainid,
            deal,
            string.concat(
                "src/DealNFT.sol:DealNFT --constructor-args $(cast abi-encode \"constructor(address,address,address,address,string,string,string)\" ",
                Strings.toHexString(registry),
                " ",
                Strings.toHexString(implementation),
                " ",
                Strings.toHexString(sponsor),
                " ",
                Strings.toHexString(treasury),
                " ",
                name,
                " ",
                symbol,
                " ",
                baseURI,
                ")\n"
            )
        );
    }
}