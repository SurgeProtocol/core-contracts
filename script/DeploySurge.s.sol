// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "forge-std/Script.sol";

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../src/Surge.sol";

contract DeploySurge is Script {
    function run() external {
        bytes32 salt = 0x6551655165516551655165516551655165516551655165516551655165516551;
        address factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

        uint256 supply = 1000000000;

        // arbitrum
        // address treasury = 0x837bb49403346a307C449Fe831cCA5C1992C57f5;

        // base
        address treasury = 0x39110eEfD8542b3308817a27EbD3509386D37754;

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