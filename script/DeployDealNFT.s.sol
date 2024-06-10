// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "../src/DealNFT.sol";

contract DeployDealNFT is Script {
    function run() external {
        bytes32 salt = 0x6551655165516551655165516551655165516551655165516551655165516553;
        address factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        address registry = 0x000000006551c19487814612e58FE06813775758;

        // arbitrum
        address implementation = 0x8A6bDD9B33D21D96112cc67B52C91719178Cc704;
        address treasury = 0x837bb49403346a307C449Fe831cCA5C1992C57f5;

        // base
        // address implementation = 0x6AE9d37F3c4240c9288059B743652b67cE20FcDD;
        // address treasury = 0x39110eEfD8542b3308817a27EbD3509386D37754;

        address sponsor = 0xF2D3Ba4Ad843Ac0842Baf487660FCb3B208c988c;
        string memory name = "Arbitrum Beta $1000 Bonus";
        string memory symbol = "SRGBETA1";
        string memory baseURI = "https://api.surge.rip";

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