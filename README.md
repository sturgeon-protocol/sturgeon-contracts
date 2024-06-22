# Sturgeon contracts

## Deployments

### Real

* Controller [0xE0E71B484Bb20E37d18Ab51fB60c32deC778478A](https://explorer.re.al/address/0xE0E71B484Bb20E37d18Ab51fB60c32deC778478A)
* IFO [0x4c5758e3c454a260d98238706ca6f4802cc52746](https://explorer.re.al/address/0x4c5758e3c454a260d98238706ca6f4802cc52746?tab=contract)
* STGN [0x22d031e45a02d6472786b9d7a4fd78f1733d6990](https://explorer.re.al/address/0x22d031e45a02d6472786b9d7a4fd78f1733d6990?tab=contract)
* veSTGN proxy [0x4f69329e8de13aa7eac664368c5858af6371fa4c](https://explorer.re.al/address/0x4f69329e8de13aa7eac664368c5858af6371fa4c?tab=contract)
* Multigauge proxy [0xbca14cf8cc2417a5b4ed242ba45ae4835af4d5df](https://explorer.re.al/address/0xbca14cf8cc2417a5b4ed242ba45ae4835af4d5df?tab=contract)
* Factory proxy [0x97b56feada7fb2d7a0a8576635f05314f184f0c2](https://explorer.re.al/address/0x97b56feada7fb2d7a0a8576635f05314f184f0c2?tab=contract)
* VeDistributor proxy [0x7dc43c0165bfc9d202fa24bef10992f599014999](https://explorer.re.al/address/0x7dc43c0165bfc9d202fa24bef10992f599014999?tab=contract)
* Frontend [0x045c8a060474874c5918717ecd55f07b62c59a90](https://explorer.re.al/address/0x045c8a060474874c5918717ecd55f07b62c59a90?tab=contract)
* DepositHelper [0xAf95468B1a624605bbFb862B0FB6e9C73Ad847b8](https://explorer.re.al/address/0xAf95468B1a624605bbFb862B0FB6e9C73Ad847b8?tab=contract)
* Compounder proxy [0x377c3bfed5e7675821f7a15ade25bc580d4c9bbb](https://explorer.re.al/address/0x377c3bfed5e7675821f7a15ade25bc580d4c9bbb?tab=contract)

### Unreal testnet

* Controller [0x4F69329E8dE13aA7EAc664368C5858AF6371FA4c](https://unreal.blockscout.com/address/0x4F69329E8dE13aA7EAc664368C5858AF6371FA4c?tab=contract)
* IFO [0x3222eb4824cEb0E9CcfE11018C83429105dFE00F](https://unreal.blockscout.com/address/0x3222eb4824cEb0E9CcfE11018C83429105dFE00F?tab=contract)
* STGN [0x609e0d74fAB81085283df92B563750624054F8bE](https://unreal.blockscout.com/address/0x609e0d74fAB81085283df92B563750624054F8bE?tab=contract)
* veSTGN proxy [0x029Dfd1a79e0AD9305d773fb8F3c01D8eF9b913d](https://unreal.blockscout.com/address/0x029Dfd1a79e0AD9305d773fb8F3c01D8eF9b913d?tab=contract)
* Multigauge proxy [0x5B0Ad247bc0Fac75d76D1337932fc29b1eCb8eE6](https://unreal.blockscout.com/address/0x5B0Ad247bc0Fac75d76D1337932fc29b1eCb8eE6?tab=contract)
* Factory proxy [0x045c8A060474874c5918717eCd55F07B62C59a90](https://unreal.blockscout.com/address/0x045c8A060474874c5918717eCd55F07B62C59a90?tab=contract)
* VeDistributor proxy [0xAf95468B1a624605bbFb862B0FB6e9C73Ad847b8](https://unreal.blockscout.com/address/0xAf95468B1a624605bbFb862B0FB6e9C73Ad847b8?tab=contract)
* Frontend [0xA38588970eD3c17C6De6A77D4E06C914B58A4F30](https://unreal.blockscout.com/address/0xA38588970eD3c17C6De6A77D4E06C914B58A4F30?tab=contract)
* DepositHelper [0x7c8d0C7B63249A314df84707F8690F62CF625820](https://unreal.blockscout.com/address/0x7c8d0C7B63249A314df84707F8690F62CF625820?tab=contract)
* Compounder proxy [0x89c06219C24ab4aBd762A49cdE97ce69B05f3EAF](https://unreal.blockscout.com/address/0x89c06219C24ab4aBd762A49cdE97ce69B05f3EAF?tab=contract)

## Develop

### Compile, test, etc

```shell
forge install
forge build
forge test -vv
forge coverage
forge fmt
```

### Deploy

```shell
forge script DeployReal --skip-simulation --broadcast --with-gas-price 300000000 --rpc-url https://real.drpc.org --slow --verify --verifier blockscout --verifier-url https://explorer.re.al/api?
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
