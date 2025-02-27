// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealFactory} from "../src/DealFactory.sol";
import {DealNFT} from "../src/DealNFT.sol";
import {StakingRelayer} from "../src/StakingRelayer.sol";

contract DealFactoryTest is Test {
    address sponsor;
    address treasury;
    address registry;
    address implementation;

    DealFactory factory;
    StakingRelayer relayer;

    function setUp() public {
        sponsor = vm.addr(1);
        treasury = vm.addr(2);
        registry = vm.addr(3);
        implementation = vm.addr(4);

        relayer = new StakingRelayer(sponsor);
    }

    function test_Create_Deal() public {
        _setup();
        address deal = _create();
        assertNotEq(deal, address(0));
    }

    function test_SetRelayer() public {
        _setup();
        vm.startPrank(sponsor);
        factory.setRelayer(address(relayer));
        relayer.setFactory(address(factory));
        vm.stopPrank();

        address deal = _create();
        assertNotEq(deal, address(0));
        assertEq(relayer.enabledDeals(deal), true);
    }

    // --- Revert tests ---
    function test_RevertWhen_ZeroAddress() public {
        vm.expectRevert(DealFactory.ZeroDetected.selector);
        new DealFactory(address(0), treasury, registry, implementation, "https://example.com/nft/");

        vm.expectRevert(DealFactory.ZeroDetected.selector);
        new DealFactory(sponsor, address(0), registry, implementation, "https://example.com/nft/");

        vm.expectRevert(DealFactory.ZeroDetected.selector);
        new DealFactory(sponsor, treasury, address(0), implementation, "https://example.com/nft/");

        vm.expectRevert(DealFactory.ZeroDetected.selector);
        new DealFactory(sponsor, treasury, registry, address(0), "https://example.com/nft/");

        vm.expectRevert(DealFactory.ZeroDetected.selector);
        new DealFactory(sponsor, treasury, registry, implementation, "");
    }

    function test_RevertWhen_TurnedOff() public {
        _setup();
        _create();
        vm.prank(sponsor);
        factory.turnOff();
        vm.expectRevert(DealFactory.FactoryTurnedOff.selector);
        _create();
    }

    function test_RevertWhen_TurnOffWithWrongOwner() public {
        _setup();
        vm.prank(treasury);
        vm.expectRevert(DealFactory.OnlyOwner.selector);
        factory.turnOff();
    }

    function test_RevertWhen_SetRelayerWithWrongOwner() public {
        _setup();
        vm.prank(treasury);
        vm.expectRevert(DealFactory.OnlyOwner.selector);
        factory.setRelayer(address(relayer));
    }

    function test_RevertWhen_SetRelayerWithZeroAddress() public {
        _setup();
        vm.prank(sponsor);
        vm.expectRevert(DealFactory.ZeroDetected.selector);
        factory.setRelayer(address(0));
    }


    // --- private functions ---
    function _setup() private {
        factory = new DealFactory(sponsor, treasury, registry, implementation, "https://example.com/nft/");
    }

    function _create() private returns (address) {
        DealNFT.Configuration memory dealConfig = DealNFT.Configuration({
            escrowToken: address(0),
            sponsor: sponsor,
            arbitrator: treasury,
            image: "https://image.jpg",
            description: "",
            social: "",
            website: "",
            multiple: 1e18,
            closingDelay: 0,
            unstakingFee: 0,
            closingTime: 0,
            dealMinimum: 0,
            dealMaximum: 0,
            deliveryType: 0,
            active: false,
            cancelled: false,
            transferable: false,
            timeBasedClosing: true
        });
        return factory.create("name", "symbol", dealConfig);
    }
}