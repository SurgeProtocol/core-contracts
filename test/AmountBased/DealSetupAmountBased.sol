// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DealNFT} from "../../src/DealNFT.sol";
import {AccountV3TBD} from "../../src/AccountV3TBD.sol";

import "multicall-authenticated/Multicall3.sol";
import "erc6551/ERC6551Registry.sol";
import "tokenbound/src/AccountGuardian.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ERC20PresetFixedSupply} from "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import {IERC20Metadata} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

contract DealSetupAmountBased is Test {
    DealNFT public deal;
    IERC20Metadata public escrowToken;

    uint256 tokenId = 0;
    uint256 amount = 1000000;
    address sponsor;
    address treasury;
    address arbitrator;
    address staker1;
    address staker2;

    function _init() internal {
        sponsor = vm.addr(1);
        treasury = vm.addr(2);
        arbitrator = vm.addr(3);

        staker1 = vm.addr(4);
        staker2 = vm.addr(5);

        escrowToken = new ERC20PresetFixedSupply("escrow", "escrow", 50000000, address(this));
        escrowToken.transfer(address(staker1), amount);
        escrowToken.transfer(address(staker2), amount);
        escrowToken.transfer(address(sponsor), amount*3);
        escrowToken.transfer(address(arbitrator), amount*3);

        ERC6551Registry registry = new ERC6551Registry();
        Multicall3 forwarder = new Multicall3();
        AccountGuardian guardian = new AccountGuardian(address(this));

        AccountV3TBD implementation = new AccountV3TBD(
            address(1),
            address(forwarder),
            address(registry),
            address(guardian)
        );

        DealNFT.Configuration memory dealConfig = DealNFT.Configuration({
            escrowToken: address(0),
            sponsor: sponsor,
            arbitrator: arbitrator,
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
            timeBasedClosing: false
        });

        deal = new DealNFT(
            treasury,
            address(registry),
            payable(address(implementation)),
            "https://test.com/chain/1/deal/",
            "SurgeDealTEST",
            "SRGTEST",
            dealConfig
        );

        vm.prank(treasury);
        deal.setArbitrator(arbitrator);

        vm.prank(staker1);
        escrowToken.approve(address(deal), amount);

        vm.prank(staker2);
        escrowToken.approve(address(deal), amount);

    }

    function _stake(address staker) internal {
        vm.prank(staker);
        deal.stake(staker, amount);
    }

    function _setup() internal {
        vm.prank(sponsor);
        deal.setup(address(escrowToken), 30 minutes, 50000, 2000000, 2000000, "https://social", "https://website", "https://image", "", 1);
    }

    function _configure() internal {
        vm.prank(sponsor);
        deal.configure("desc", "https://social", "https://website", 0, 0, 0, 5e18);
    }

    function _activate() internal {
        vm.prank(sponsor);
        deal.activate();
    }

    function _depositDeliveryTokens() internal {
        vm.startPrank(arbitrator);
        escrowToken.approve(address(deal), amount*3);
        deal.depositDeliveryTokens(address(escrowToken), amount*3);
        vm.stopPrank();
    }
}
