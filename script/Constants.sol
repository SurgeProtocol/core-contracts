// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

contract Constants {

    mapping(uint256 => address) public treasury;
    mapping(uint256 => address) public implementation;

    bytes32 public salt = 0x6551655165516551655165516551655165516551655165516551655165516551;
    address public factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    address public registry = 0x000000006551c19487814612e58FE06813775758;
    address public sponsor = 0xF2D3Ba4Ad843Ac0842Baf487660FCb3B208c988c;
    string public baseURI = "https://api.surge.rip";

    constructor() {
        // bob
        treasury[60808] = 0x39110eEfD8542b3308817a27EbD3509386D37754;
        implementation[60808] = 0x6227a8a36Ad91C1ea96bb3bAe7Bc802913bb8c61;

        // base
        treasury[8453] = 0x39110eEfD8542b3308817a27EbD3509386D37754;
        implementation[8453] = 0x951C52FFA6feF92C883Fd49F762394e5066888A1;

        // arbitrum
        treasury[42161] = 0x837bb49403346a307C449Fe831cCA5C1992C57f5;
        implementation[42161] = 0xe11e02Ac7FCd2474Af531e12d272f71aC2E11488;
    }
}
