// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IDealNFT} from "./interfaces/IDealNFT.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

contract StakingRelayer {
    using SafeERC20 for IERC20Metadata;
    mapping(address => bool) public enabledDeals;

    address private immutable _owner;
    address private _factory;

    constructor(address owner_) {
        _owner = owner_;
    }

    function stake(address dealAddress, uint256 amount) external {
        require(enabledDeals[dealAddress], "StakingRelayer: deal not allowed");
        IERC20Metadata escrowToken = IDealNFT(dealAddress).escrowToken();

        escrowToken.safeTransferFrom(msg.sender, address(this), amount);
        escrowToken.safeApprove(dealAddress, amount);

        IDealNFT(dealAddress).stake(msg.sender, amount);
    }

    function enableDeal(address dealAddress) external {
        require(msg.sender == _owner || msg.sender == _factory, "StakingRelayer: not owner or factory");
        enabledDeals[dealAddress] = true;
    }

    function disableDeal(address dealAddress) external {
        require(msg.sender == _owner, "StakingRelayer: not owner");
        enabledDeals[dealAddress] = false;
    }

    function setFactory(address factory) external {
        require(msg.sender == _owner, "StakingRelayer: not owner");
        _factory = factory;
    }
}
