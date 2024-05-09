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
        address multicallForwarder_,
        address erc6551Registry_,
        address guardian_
    ) AccountV3(entryPoint_, multicallForwarder_, erc6551Registry_, guardian_) {}

    function approve() public {
        (, address tokenContract, ) = token();
        IERC20 escrowToken = IDealNFT(tokenContract).escrowToken();
        escrowToken.safeApprove(tokenContract, type(uint256).max);
    }

    function _beforeExecute(address to, uint256 value, bytes memory data, uint8 operation) internal override {
        (, address tokenContract, ) = token();
        require(IDealNFT(tokenContract).allowToken(to), "Cannot use the escrow token");
        super._beforeExecute(to, value, data, operation);
    }
}
