## Surge!

**Staking pools that allow you to buy deals before they have terms**

Surge "Deals" are a type of NFT that implements a variation of [Token Bound Accounts](https://tokenbound.org/) or TBAs. We call this variation TBD, or "Token Bound Deposits".
A TBD accepts stakes (escrow deposits) of a specific type of token. Then, it applies rules to control unstaking (by the contributor) or claiming (by the deal sponsor).

## Documentation

https://docs.surge.rip/

## Usage
The Sponsor constructs a Deal, with an NFT and terms for stakers. The deal becomes active for staking, reaches a close, and might be claimed.

### Test

```shell
$ forge test

### Deploy

```shell
$ forge script script/DeployAccountV3TBD.s.sol:AccountV3TBDScript --rpc-url <rpc_url> --private-key <private_key>
$ forge script script/DeployDealNFT.s.sol:DealScript --rpc-url <rpc_url> --private-key <private_key>
```
