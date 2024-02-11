// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/interfaces/IVault.sol";
import "../src/HarvesterVault.sol";
import "../src/interfaces/IMultiPool.sol";
import "../src/IFO.sol";
import "../src/PearlStrategyCustomIFO.sol";


contract DeployCustomIfoVaultAndStrategy is Script {
    address public constant CONTROLLER = 0x4F69329E8dE13aA7EAc664368C5858AF6371FA4c;
    address public constant STGN = 0x609e0d74fAB81085283df92B563750624054F8bE;
    address public constant PEARL_TOKEN = 0xCE1581d7b4bA40176f0e219b2CaC30088Ad50C7A;

    function run() external {
        address underlying = 0xAB5a4189e947E0e3EbEc25637f73deb55f6CEEA9;
        address pearlGauge = 0x54CbD289B263CD14E6707EcbDa01161c4385DFe3;

        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IFO ifo = new IFO(12e17);
        ifo.setup(CONTROLLER, STGN, PEARL_TOKEN);

        address vault = address(
            new HarvesterVault(
                CONTROLLER,
                IERC20(underlying),
                "IFO Harvester DAI-USDC custom",
                "ifocTDT-DAI-USDC",
                4_000
            )
        );
        address strategy = address(new PearlStrategyCustomIFO(address(ifo), vault, pearlGauge, true, address(0)));
        IVault(vault).setStrategy(strategy);
        address multigauge = IController(CONTROLLER).multigauge();
        IGauge(multigauge).addStakingToken(vault);
        IController(CONTROLLER).registerVault(vault, true);

        vm.stopBroadcast();
    }

    function testDeploy_() external {}
}
