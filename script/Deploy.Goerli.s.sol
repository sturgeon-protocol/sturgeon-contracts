// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../chains/GoerliLib.sol";
import "../src/HarvesterVault.sol";
import "../src/PearlStrategy.sol";
import "../src/CompounderVault.sol";
import "../test/mock/MockERC20.sol";
import "../test/mock/MockPearlGaugeV2.sol";

contract DeployGoerli is Script {
    function run() external {
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        console.log("deployer", vm.addr(deployerPrivateKey));

        // deploy mocks
        address tokenA = address(new MockERC20("Mock Token A", "MOCK_A", 18));
        address tokenC = address(new MockERC20("Mock Token C", "MOCK_C", 18));
        address tokenD = address(new MockERC20("Mock Token D", "MOCK_D", 18));
        IGaugeV2ALM pearlGauge = IGaugeV2ALM(address(new MockPearlGaugeV2(tokenA, tokenC)));

        IController controller = IController(GoerliLib.runDeploy(tokenC, true));
        Factory factory = Factory(controller.factory());

        // deploy IFO harvester
        factory.deployIfoHarvester(tokenA, address(pearlGauge), "IFO Harvester MOCK_A", "xTokenA");

        // deploy compounder + harvester
        CompounderVault compounderVault =
            CompounderVault(factory.deployCompounder(tokenD, "Compounder vault for xTokenA", "xxTokenA"));
        factory.deployHarvester(tokenA, address(pearlGauge), "Harvester MOCK_A", "xTokenA", address(compounderVault));

        vm.stopBroadcast();
    }

    function testDeployPolygon() external {}
}
