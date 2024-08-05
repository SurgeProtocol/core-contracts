// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {DealNFT} from "./DealNFT.sol";

contract DealFactory {

    event Create(address indexed deal, address indexed sponsor, string name, string symbol);

    bool private _active;
    address private immutable _owner;

    address private immutable _registry;
    address private immutable _implementation;
    address private immutable _treasury;
    string private _baseURI;

    constructor(
        address owner_,
        address registry_,
        address implementation_,
        address treasury_,
        string memory baseURI_
    ) {
        require(registry_ != address(0), "registry is the zero address");
        require(implementation_ != address(0), "implementation is the zero address");
        require(treasury_ != address(0), "treasury is the zero address");
        require(bytes(baseURI_).length > 0, "baseURI is empty");

        _active = true;
        _owner = owner_;
        _registry = registry_;
        _implementation = implementation_;
        _treasury = treasury_;
        _baseURI = baseURI_;
    }

    function create(
        address sponsor_,
        string memory name_,
        string memory symbol_
    ) external returns (address)  {
        require(_active, "factory has been turned off");
        require(sponsor_ != address(0), "sponsor is the zero address");
        require(bytes(name_).length > 0, "name is empty");
        require(bytes(symbol_).length > 0, "symbol is empty");

        DealNFT deal = new DealNFT(
            _registry,
            _implementation,
            sponsor_,
            _treasury,
            name_,
            symbol_,
            _baseURI
        );

        emit Create(address(deal), sponsor_, name_, symbol_);

        return address(deal);
    }

    function turnOff() external {
        require(msg.sender == _owner, "only owner can turn off");
        _active = false;
    }
}
