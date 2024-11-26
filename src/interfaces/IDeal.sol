// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IWhitelist} from "./IWhitelist.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {DealNFT} from "../DealNFT.sol";

interface IDeal {
    enum State { Setup, Active, Claiming, Closed, Cancelled }

    struct StakeData {
        address owner;
        address tba;
        uint256 staked;
        uint256 claimed;
    }

    struct DealData {
        address sponsor;
        address arbitrator;
        IWhitelist stakersWhitelist;
        IWhitelist claimsWhitelist;
        address escrowToken;
        address deliveryToken;
        uint256 closingTime;
        uint256 closingDelay;
        uint256 totalClaimed;
        uint256 totalStaked;
        uint256 multiple;
        uint256 dealMinimum;
        uint256 dealMaximum;
        uint256 unstakingFee;
        uint256 nextId;
        State state;
        string social;
        string description;
        string website;
        string name;
        string symbol;
        string image;

        string escrowName;
        string escrowSymbol;
        uint8 escrowDecimals;
        StakeData[] claimed;
        bool transferable;
        uint256 deliveryType;
    }

    struct DealShortData {
        string name;
        string image;
        string symbol;
        State state;
        string description;
    }

    function getConfiguration() external view returns (DealNFT.Configuration memory);
    function deliveryToken() external view returns (IERC20Metadata);
    function totalClaimed() external view returns (uint256);
    function totalStaked() external view returns (uint256);
    function getStakesTo(uint256 id) external view returns (StakeData[] memory);
    function nextId() external view returns (uint256);
    function state() external view returns (State);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function stakersWhitelist() external view returns (IWhitelist);
    function claimsWhitelist() external view returns (IWhitelist);
}
