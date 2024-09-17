// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {IDeal} from "./interfaces/IDeal.sol";

contract Reader {

    function getDeal(address dealAddress) external view returns (IDeal.DealData memory deal) {
        IDeal dealInstance = IDeal(dealAddress);
        IERC20Metadata escrowToken = dealInstance.escrowToken();

        string memory _escrowName;
        string memory _escrowSymbol;
        uint8 _escrowDecimals = 6;

        if(address(escrowToken) != address(0)){
            _escrowName = escrowToken.name();
            _escrowSymbol = escrowToken.symbol();
            _escrowDecimals = escrowToken.decimals();
        }

        uint256 _nextId = dealInstance.nextId();
        IDeal.StakeData[] memory _claimed = new IDeal.StakeData[](_nextId);
        if(_nextId > 0){
            _claimed = dealInstance.getStakesTo(_nextId);
        }

        deal = IDeal.DealData({
            sponsor: dealInstance.sponsor(),
            arbitrator: dealInstance.arbitrator(),
            stakersWhitelist: dealInstance.stakersWhitelist(),
            claimsWhitelist: dealInstance.claimsWhitelist(),
            escrowToken: dealInstance.escrowToken(),
            deliveryToken: dealInstance.deliveryToken(),
            closingTime: dealInstance.closingTime(),
            closingDelay: dealInstance.closingDelay(),
            totalClaimed: dealInstance.totalClaimed(),
            totalStaked: dealInstance.totalStaked(),
            multiple: dealInstance.multiple(),
            dealMinimum: dealInstance.dealMinimum(),
            dealMaximum: dealInstance.dealMaximum(),
            unstakingFee: dealInstance.unstakingFee(),
            nextId: _nextId,
            state: dealInstance.state(),
            social: dealInstance.social(),
            description: dealInstance.description(),
            website: dealInstance.website(),
            name: dealInstance.name(),
            symbol: dealInstance.symbol(),
            image: dealInstance.image(),
            escrowName: _escrowName,
            escrowSymbol: _escrowSymbol,
            escrowDecimals: _escrowDecimals,
            claimed: _claimed,
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

