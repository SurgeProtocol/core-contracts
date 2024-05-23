// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract Surge is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("SurgeTST", "SRGTST") ERC20Permit("Surge") {
        // TODO: move to multisig, define amount, remove TST
        _mint(0x7Adc86401f246B87177CEbBEC189dE075b75Af3A, 1000000000 * 10 ** decimals());
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _burn(address account, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    function _mint(address account, uint256 amount)
        internal override(ERC20, ERC20Votes)
    {
        super._mint(account, amount);
    }
}
