// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {DealNFT} from "./DealNFT.sol";
import {StakingRelayer} from "./StakingRelayer.sol";

contract DealFactory {

    event Create(address indexed deal, address indexed sponsor, string name, string symbol, string image, string description);

    bool private _active;
    address private _relayer;
    address private immutable _owner;
    address private immutable _treasury;
    address private immutable _registry;
    address private immutable _implementation;    
    string private _nftURI;

    error FactoryTurnedOff();
    error ZeroDetected();
    error OnlyOwner();

    constructor(
        address owner_,
        address treasury_,
        address registry_,
        address implementation_,
        string memory nftURI_
    ) {
        if(owner_ == address(0)) revert ZeroDetected();
        if(treasury_ == address(0)) revert ZeroDetected();
        if(registry_ == address(0)) revert ZeroDetected();
        if(implementation_ == address(0)) revert ZeroDetected();
        if(bytes(nftURI_).length == 0) revert ZeroDetected();

        _owner = owner_;
        _treasury = treasury_;
        _registry = registry_;
        _implementation = implementation_;        
        _nftURI = nftURI_;

        _active = true;
    }

    function create(
        string memory name_,
        string memory symbol_,
        DealNFT.Configuration memory config_
    ) external returns (address)  {
        if(!_active) revert FactoryTurnedOff();

        DealNFT deal = new DealNFT(
            _treasury,
            _registry,
            _implementation,
            _nftURI,            
            name_,
            symbol_,
            config_
        );

        if (_relayer != address(0)) {
            StakingRelayer(_relayer).enableDeal(address(deal));
        }

        emit Create(address(deal), config_.sponsor, name_, symbol_, config_.image, config_.description);

        return address(deal);
    }

    function turnOff() external {
        if(msg.sender != _owner) revert OnlyOwner();
        _active = false;
    }

    function setRelayer(address relayer_) external {
        if(msg.sender != _owner) revert OnlyOwner();
        if(relayer_ == address(0)) revert ZeroDetected();
        _relayer = relayer_;
    }
}
