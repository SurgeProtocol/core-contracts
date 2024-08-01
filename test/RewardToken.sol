// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;


import {ERC20PresetFixedSupply} from "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract RewardToken is ERC20PresetFixedSupply {
    /**
     * @dev Mints `initialSupply` amount of token and transfers them to `owner`.
     *
     * See {ERC20-constructor}.
     */
    constructor(string memory name, string memory symbol, uint256 initialSupply, address owner) ERC20PresetFixedSupply(name, symbol,initialSupply, owner) {

    }

    function decimals() public pure override returns (uint8) {
        return 12;
    }
    
}
