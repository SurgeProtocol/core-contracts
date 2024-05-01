// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {AccountV3} from "tokenbound/src/AccountV3.sol";
import {IDealNFT} from "./interfaces/IDealNFT.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract AccountV3TBD is AccountV3 {
    using SafeERC20 for IERC20;
    
    constructor(
        address entryPoint_,
        address multicallForwarder,
        address erc6551Registry,
        address guardian
    ) AccountV3(entryPoint_, multicallForwarder, erc6551Registry, guardian) {}

    function approve() public {
        (, address tokenContract, ) = token();
        IERC20 escrowToken = IDealNFT(tokenContract).escrowToken();
        escrowToken.safeApprove(tokenContract, type(uint256).max);
    }

    function _beforeExecute(address to, uint256 value, bytes memory data, uint8 operation) internal override {
        (, address tokenContract, ) = token();
        IERC20 escrowToken = IDealNFT(tokenContract).escrowToken();
        require(to != address(escrowToken), "Cannot use the escrow token");
        super._beforeExecute(to, value, data, operation);
    }
}
