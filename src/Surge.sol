// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract Surge is ERC20, ERC20Permit, ERC20Votes {

    constructor(address mintTo, uint256 totalSupply)
        ERC20("SurgeTST", "SRGTST") ERC20Permit("Surge")
    {
        _mint(mintTo, totalSupply * 10 ** decimals());
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
