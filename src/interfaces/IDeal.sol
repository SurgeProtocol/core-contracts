// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IWhitelist} from "./IWhitelist.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

interface IDeal {
    enum State { Setup, Active, Claiming, Closed, Canceled }

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
        IERC20Metadata escrowToken;
        IERC20Metadata rewardToken;
        uint256 closingTime;
        uint256 closingDelay;
        uint256 totalClaimed;
        uint256 totalStaked;
        uint256 multiplier;
        uint256 dealMinimum;
        uint256 dealMaximum;
        uint256 unstakingFee;
        uint256 nextId;
        State state;
        string twitter;
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
    }

    struct DealShortData {
        string name;
        string image;
        string symbol;
        State state;
        string description;
    }

    function escrowToken() external view returns (IERC20Metadata);
    function rewardToken() external view returns (IERC20Metadata);
    function transferable() external view returns (bool);
    function closingTime() external view returns (uint256);
    function closingDelay() external view returns (uint256);
    function totalClaimed() external view returns (uint256);
    function totalStaked() external view returns (uint256);
    function multiplier() external view returns (uint256);
    function dealMinimum() external view returns (uint256);
    function dealMaximum() external view returns (uint256);
    function unstakingFee() external view returns (uint256);
    function nextId() external view returns (uint256);
    function sponsor() external view returns (address);
    function arbitrator() external view returns (address);
    function stakersWhitelist() external view returns (IWhitelist);
    function claimsWhitelist() external view returns (IWhitelist);
    function state() external view returns (State);
    function twitter() external view returns (string memory);
    function description() external view returns (string memory);
    function website() external view returns (string memory);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function image() external view returns (string memory);
    function getStakesTo(uint256 id) external view returns (StakeData[] memory);
}
