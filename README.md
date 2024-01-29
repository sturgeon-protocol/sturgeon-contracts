# Sturgeon contracts

## Usage

### Compile, test, etc

```shell
forge install
forge build
forge test -vv
forge coverage
forge fmt
```

### Add liquidator routes

Example of adding USDC-DAI route for Unreal testnet:

```shell
cast send -i --legacy --rpc-url https://rpc.unreal.gelato.digital 0xE0D142466d1BF88FE23D5D265d76068077E4D6F0 'addLargestPools((address,address,address,address)[],bool)' '[("0x1933cB66cB5A2b47A93753773C556ab6CA825831","0x95b012C1D02c859dab6b302F4b72941Ba4E3C3C3","0xabAa4C39cf3dF55480292BBDd471E88de8Cc3C97","0x665D4921fe931C0eA1390Ca4e0C422ba34d26169")]' false
```

### View underlying share price

```shell
cast call --rpc-url https://rpc.unreal.gelato.digital 0x35bf701C24357FD0C7F60376044323A2a830ad78 'getLiquidBoxSharePrice(address,address)(uint256)' 0x67048eA97Ca5DFDAe111A2304af1aED5115C7946 0xabAa4C39cf3dF55480292BBDd471E88de8Cc3C97
```

## Deployments

### Unreal testnet

* Controller 0x4F69329E8dE13aA7EAc664368C5858AF6371FA4c [Blockscout](https://unreal.blockscout.com/address/0x4F69329E8dE13aA7EAc664368C5858AF6371FA4c?tab=contract)
* IFO 0x3222eb4824cEb0E9CcfE11018C83429105dFE00F [Blockscout](https://unreal.blockscout.com/address/0x3222eb4824cEb0E9CcfE11018C83429105dFE00F?tab=contract)
* STGN 0x609e0d74fAB81085283df92B563750624054F8bE [Blockscout](https://unreal.blockscout.com/address/0x609e0d74fAB81085283df92B563750624054F8bE?tab=contract)
* veSTGN proxy 0x029Dfd1a79e0AD9305d773fb8F3c01D8eF9b913d [Blockscout](https://unreal.blockscout.com/address/0x029Dfd1a79e0AD9305d773fb8F3c01D8eF9b913d?tab=contract)
* Multigauge proxy 0x5B0Ad247bc0Fac75d76D1337932fc29b1eCb8eE6 [Blockscout](https://unreal.blockscout.com/address/0x5B0Ad247bc0Fac75d76D1337932fc29b1eCb8eE6?tab=contract)
* Factory proxy 0x045c8A060474874c5918717eCd55F07B62C59a90 [Blockscout](https://unreal.blockscout.com/address/0x045c8A060474874c5918717eCd55F07B62C59a90?tab=contract)
* VeDistributor proxy 0xAf95468B1a624605bbFb862B0FB6e9C73Ad847b8 [Blockscout](https://unreal.blockscout.com/address/0xAf95468B1a624605bbFb862B0FB6e9C73Ad847b8?tab=contract)
* Frontend 0xA38588970eD3c17C6De6A77D4E06C914B58A4F30 [Blockscout](https://unreal.blockscout.com/address/0xA38588970eD3c17C6De6A77D4E06C914B58A4F30?tab=contract)
* DepositHelper 0x7c8d0C7B63249A314df84707F8690F62CF625820 [Blockscout](https://unreal.blockscout.com/address/0x7c8d0C7B63249A314df84707F8690F62CF625820?tab=contract)
* Compounder proxy 0x89c06219C24ab4aBd762A49cdE97ce69B05f3EAF [Blockscout](https://unreal.blockscout.com/address/0x89c06219C24ab4aBd762A49cdE97ce69B05f3EAF?tab=contract)

### Goerli testnet

* Controller 0x8216C9afFC982428aF33D1D9F165bAf9D75AebBa
* IFO 0x029Dfd1a79e0AD9305d773fb8F3c01D8eF9b913d
* STGN 0x5B0Ad247bc0Fac75d76D1337932fc29b1eCb8eE6
* veSTGN proxy 0x87eDeA5aea52BA12Ebf4eBc253Ec3218C1090C70
* Multigauge 0xAf95468B1a624605bbFb862B0FB6e9C73Ad847b8
* Factory 0xBD5296DC2603942F116B375c8Ee373674be86f56
* VeDistributor proxy 0x7c8d0C7B63249A314df84707F8690F62CF625820
* MockGauge 0x54F22378E03BeA25a05A071b60357d31Ce535Bb9
* MockLiquidator 0x97B56FEAdA7fb2D7A0A8576635f05314f184f0C2
* MockA 0xBcA14CF8Cc2417a5B4ed242bA45aE4835aF4d5Df
* MockC 0x609e0d74fAB81085283df92B563750624054F8bE
* MockD 0x635B1F7dD7d0172533BA9fE5Cfe2D83D9848f701
