// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/interfaces/IVault.sol";
import "../src/HarvesterVault.sol";
import "../src/PearlStrategy.sol";
import "../src/interfaces/IMultiPool.sol";


contract DeployVaultAndStrategy is Script {
    address public constant CONTROLLER = 0x4F69329E8dE13aA7EAc664368C5858AF6371FA4c;

    function run() external {
        address underlying = 0xAB5a4189e947E0e3EbEc25637f73deb55f6CEEA9;
        address pearlGauge = 0x54CbD289B263CD14E6707EcbDa01161c4385DFe3;
        address compounderVault = 0xE983c2da7Ef6bFFF9b0b10ADdBF2f0E1ed9b5043;

        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address vault = address(
            new HarvesterVault(
                CONTROLLER,
                IERC20(underlying),
                "Harvester DAI-USDC (New)",
                "xTDT-DAI-USDC",
                4_000
            )
        );
        address strategy = address(new PearlStrategy(vault, pearlGauge, false, compounderVault));
        IVault(vault).setStrategy(strategy);
        address multigauge = IController(CONTROLLER).multigauge();
        IGauge(multigauge).addStakingToken(vault);
        IMultiPool(multigauge).registerRewardToken(vault, compounderVault);
        IController(CONTROLLER).registerVault(vault, true);

        vm.stopBroadcast();
    }

    function testDeploy_() external {}
}
