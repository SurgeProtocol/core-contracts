
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./gen_schema.sol";
import "./gen_events.sol";
import "./gen_base.sol";
import "./gen_helpers.sol";

interface IDeal {
    function totalStaked() external view returns (uint256);
}

interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract MyIndex is GhostGraph {
    using StringHelpers for EventDetails;
    using StringHelpers for uint256;
    using StringHelpers for address;

    function registerHandles() external {
        graph.registerFactory(0xA831B98cD0190bC973cAfd0551BfCfed0Ff3f510, GhostEventName.Create, "deal");
        graph.registerHandle(0xA831B98cD0190bC973cAfd0551BfCfed0Ff3f510);
    }

    function onCreate(EventDetails memory details, CreateEvent memory ev) external {
        Deal memory deal = graph.getDeal(ev.deal);

        deal.sponsor = ev.sponsor;
        deal.arbitrator = ev.arbitrator;

        deal.escrowToken = ev.escrowToken;
        deal.escrowSymbol = IERC20(ev.escrowToken).symbol();
        deal.escrowDecimals = IERC20(ev.escrowToken).decimals();

        deal.name = ev.name;
        deal.symbol = ev.symbol;
        deal.image = ev.image;
        deal.description = ev.description;

        deal.txHash = details.transactionHash;
        deal.createdAt = details.timestamp;

        graph.saveDeal(deal);
    }

    function onInit(EventDetails memory details, InitEvent memory ev) external {
        Deal memory deal = graph.getDeal(details.emitter);

        deal.social = ev.social;
        deal.website = ev.website;
        deal.multiple = ev.multiple;
        deal.closingDelay = ev.closingDelay;
        deal.unstakingFee = ev.unstakingFee;
        deal.closingTime = ev.closingTime;
        deal.dealMinimum = ev.dealMinimum;
        deal.dealMaximum = ev.dealMaximum;
        deal.deliveryType = ev.deliveryType;
        deal.transferable = ev.transferable;

        if(ev.active){
            deal.state = 1;
        }

        graph.saveDeal(deal);
    }

    function onSetup(EventDetails memory details, SetupEvent memory ev) external {
        Deal memory deal = graph.getDeal(details.emitter);

        deal.escrowToken = ev.escrowToken;
        deal.escrowSymbol = IERC20(ev.escrowToken).symbol();
        deal.escrowDecimals = IERC20(ev.escrowToken).decimals();

        deal.closingDelay = ev.closingDelay;
        deal.unstakingFee = ev.unstakingFee;
        deal.website = ev.website;
        deal.social = ev.social;
        deal.image = ev.image;
        deal.description = ev.description;
        deal.deliveryType = ev.deliveryType;

        graph.saveDeal(deal);
    }

    function onConfigure(EventDetails memory details, ConfigureEvent memory ev) external {
        Deal memory deal = graph.getDeal(details.emitter);

        deal.description = ev.description;
        deal.social = ev.social;
        deal.website = ev.website;
        deal.closingTime = ev.closingTime;
        deal.dealMinimum = ev.dealMinimum;
        deal.dealMaximum = ev.dealMaximum;
        deal.multiple = ev.multiple;

        graph.saveDeal(deal);
    }

    function onTransferable(EventDetails memory details, TransferableEvent memory ev) external {
        Deal memory deal = graph.getDeal(details.emitter);
        deal.transferable = ev.transferable;
        graph.saveDeal(deal);
    }

    function onArbitratorUpdated(EventDetails memory details, ArbitratorUpdatedEvent memory ev) external {
        Deal memory deal = graph.getDeal(details.emitter);
        deal.arbitrator = ev.arbitrator;
        graph.saveDeal(deal);
    }

    function onStateUpdated(EventDetails memory details, StateUpdatedEvent memory ev) external {
        Deal memory deal = graph.getDeal(details.emitter);
        deal.state = ev.state;
        graph.saveDeal(deal);
    } 

    function onStake(EventDetails memory details, StakeEvent memory ev) external {
        // DEAL
        Deal memory deal = graph.getDeal(details.emitter);
        deal.totalStaked = IDeal(details.emitter).totalStaked();
        deal.lastStakeTime = details.timestamp;
        deal.lastStakeTxHash = details.transactionHash;
        graph.saveDeal(deal);

        // STAKE
        string memory id = getStakeId(details.emitter, ev.tokenId);
        Stake memory stake = graph.getStake(id);
        stake.dealId = details.emitter;
        stake.staked = ev.amount;
        stake.owner = ev.staker;
        stake.tba = ev.tokenBoundAccount;
        stake.tokenId = ev.tokenId;
        stake.createdAt = details.timestamp;
        stake.txHash = details.transactionHash;
        graph.saveStake(stake);
    }

    function onUnstake(EventDetails memory details, UnstakeEvent memory ev) external {
        // DEAL
        Deal memory deal = graph.getDeal(details.emitter);
        deal.totalStaked = IDeal(details.emitter).totalStaked();
        graph.saveDeal(deal);

        // STAKE
        string memory id = getStakeId(details.emitter, ev.tokenId);
        Stake memory stake = graph.getStake(id);
        stake.staked = 0;
        graph.saveStake(stake);
    }

    function onRecover(EventDetails memory details, RecoverEvent memory ev) external {
        string memory id = getStakeId(details.emitter, ev.tokenId);
        Stake memory stake = graph.getStake(id);
        stake.staked = stake.claimed;
        graph.saveStake(stake);
    }

    function onClaim(EventDetails memory details, ClaimEvent memory ev) external {
        string memory id = getStakeId(details.emitter, ev.tokenId);
        Stake memory stake = graph.getStake(id);
        stake.claimed = ev.amount;
        graph.saveStake(stake);
    }

    // HELPER
    function getStakeId(address deal, uint256 token) private returns(string memory){
        return string(abi.encodePacked(deal.toString(), ":", token.toString()));
    }
}
