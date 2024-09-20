// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {Whitelists} from "./Whitelists.sol";

contract WhitelistFactory {
    event Create(address indexed whitelist);

    function create(address sponsor_) external returns (address) {
        Whitelists whitelist = new Whitelists(sponsor_);
        emit Create(address(whitelist));
        return address(whitelist);
    }
}
