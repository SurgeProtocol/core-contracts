// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GoSurge is ERC20 {
    uint256 public constant MINT_AMOUNT = 100e18;

    constructor() ERC20("GoSurge", "GOSURGE") {}

    function mint(address to) external {
        _mint(to, MINT_AMOUNT);
    }
}