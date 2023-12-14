// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../chains/TestnetLib.sol";
import "../src/HarvesterVault.sol";
import "../src/PearlStrategy.sol";
import "../src/CompounderVault.sol";
import "../test/mock/MockERC20.sol";
import "../test/mock/MockPearlGaugeV2.sol";

contract DeployTestnet is Script {
    function run() external {
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        console.log('deployer', vm.addr(deployerPrivateKey));
        IController controller = IController(TestnetLib.runDeploy(true));

        // deploy mocks
        address tokenA = address(new MockERC20("Mock Token A", "MOCK_A", 18));
        address tokenC = address(new MockERC20("Mock Token C", "MOCK_C", 18));
        address tokenD = address(new MockERC20("Mock Token D", "MOCK_D", 18));
        IPearlGaugeV2 pearlGauge = IPearlGaugeV2(address(new MockPearlGaugeV2(tokenA, tokenC)));

        // deploy IFO harvester
        HarvesterVault vault = new HarvesterVault(address(controller), IERC20(tokenA), "IFO Harvester MOCK_A", "xTokenA", 4_000);
        PearlStrategy strategy = new PearlStrategy(address(vault), address(pearlGauge), true, address(0));
        vault.setStrategy(address(strategy));
        IGauge(controller.multigauge()).addStakingToken(address(vault));

        // deploy compounder + harvester
        vault = new HarvesterVault(address(controller), IERC20(tokenA), "Harvester MOCK_A", "xTokenA", 4_000);

        CompounderVault compounderVault = new CompounderVault(IERC20(tokenD), "Compounder vault for xTokenA", "xxTokenA");

        strategy = new PearlStrategy(address(vault), address(pearlGauge), false, address(compounderVault));
        vault.setStrategy(address(strategy));

        IGauge(controller.multigauge()).addStakingToken(address(vault));
        IMultiPool(controller.multigauge()).registerRewardToken(address(vault), address(compounderVault));

        vm.stopBroadcast();
    }

    function testDeployPolygon() external {}
}
