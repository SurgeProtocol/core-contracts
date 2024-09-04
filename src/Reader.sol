// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {IDeal} from "./interfaces/IDeal.sol";

contract Reader{

    function getDeal(address dealAddress) external view returns (IDeal.DealData memory deal) {
        IDeal dealInstance = IDeal(dealAddress);
        IERC20Metadata escrowToken = dealInstance.escrowToken();
        uint256 _nextId = dealInstance.nextId();

        deal = IDeal.DealData({
            sponsor: dealInstance.sponsor(),
            arbitrator: dealInstance.arbitrator(),
            stakersWhitelist: dealInstance.stakersWhitelist(),
            claimsWhitelist: dealInstance.claimsWhitelist(),
            escrowToken: dealInstance.escrowToken(),
            rewardToken: dealInstance.rewardToken(),
            closingTime: dealInstance.closingTime(),
            closingDelay: dealInstance.closingDelay(),
            totalClaimed: dealInstance.totalClaimed(),
            totalStaked: dealInstance.totalStaked(),
            multiplier: dealInstance.multiplier(),
            dealMinimum: dealInstance.dealMinimum(),
            dealMaximum: dealInstance.dealMaximum(),
            unstakingFee: dealInstance.unstakingFee(),
            nextId: _nextId,
            state: dealInstance.state(),
            twitter: dealInstance.twitter(),
            description: dealInstance.description(),
            website: dealInstance.website(),
            name: dealInstance.name(),
            symbol: dealInstance.symbol(),
            image: dealInstance.image(),
            escrowName: escrowToken.name(),
            escrowSymbol: escrowToken.symbol(),
            escrowDecimals: escrowToken.decimals(),
            claimed: dealInstance.getStakesTo(_nextId),
            transferable: dealInstance.transferable()
        });
    }

    function getShortDeal(address dealAddress) external view returns (IDeal.DealShortData memory deal) {
        IDeal dealInstance = IDeal(dealAddress);

        deal = IDeal.DealShortData({
            name: dealInstance.name(),
            image: dealInstance.image(),
            symbol: dealInstance.symbol(),
            state: dealInstance.state(),
            description: dealInstance.description()
        });
    }
}

