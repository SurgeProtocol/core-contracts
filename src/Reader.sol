// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {IDeal} from "./interfaces/IDeal.sol";
import {DealNFT} from "./DealNFT.sol";

contract Reader {

    function getDeal(address dealAddress) external view returns (IDeal.DealData memory deal) {
        IDeal dealInstance = IDeal(dealAddress);
        DealNFT.Configuration memory config = dealInstance.getConfiguration();
        IERC20Metadata escrowToken = IERC20Metadata(config.escrowToken);

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
            escrowToken: config.escrowToken,
            sponsor: config.sponsor,
            arbitrator: config.arbitrator,
            image: config.image,
            description: config.description,
            social: config.social,
            website: config.website,
            multiple: config.multiple,
            closingDelay: config.closingDelay,
            closingTime: config.closingTime,
            unstakingFee: config.unstakingFee,
            dealMinimum: config.dealMinimum,
            dealMaximum: config.dealMaximum,
            deliveryType: config.deliveryType,
            transferable: config.transferable,
            timeBasedClosing: config.timeBasedClosing,
            stakersWhitelist: dealInstance.stakersWhitelist(),
            claimsWhitelist: dealInstance.claimsWhitelist(),
            deliveryToken: address(dealInstance.deliveryToken()),
            totalClaimed: dealInstance.totalClaimed(),
            totalStaked: dealInstance.totalStaked(),
            state: dealInstance.state(),
            name: dealInstance.name(),
            symbol: dealInstance.symbol(),
            escrowName: _escrowName,
            escrowSymbol: _escrowSymbol,
            escrowDecimals: _escrowDecimals,
            claimed: _claimed,
            nextId: _nextId
        });
    }

    function getShortDeal(address dealAddress) external view returns (IDeal.DealShortData memory deal) {
        IDeal dealInstance = IDeal(dealAddress);
        DealNFT.Configuration memory config = dealInstance.getConfiguration();

        deal = IDeal.DealShortData({
            name: dealInstance.name(),
            symbol: dealInstance.symbol(),
            state: dealInstance.state(),
            image: config.image,
            description: config.description
        });
    }
}

