// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {WhitelistFactory} from "../src/WhitelistFactory.sol";
import {Whitelists} from "../src/Whitelists.sol";

contract WhitelistFactoryTest is Test {
    address sponsor;
    WhitelistFactory factory;

    function setUp() public {
        sponsor = vm.addr(1);
        factory = new WhitelistFactory();
    }

    function test_CreateWhitelist() public {
        address whitelist = factory.create(sponsor);
        assertEq(Whitelists(whitelist).sponsor(), sponsor);
    }
}