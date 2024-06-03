// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../chains/UnrealLib.sol";
import "../src/HarvesterVault.sol";
import "../src/PearlStrategy.sol";
import "../src/CompounderVault.sol";
import "../test/mock/MockERC20.sol";
import "../test/mock/MockPearlGaugeV2.sol";

contract DeployUnreal is Script {
    function run() external {
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        console.log("deployer", vm.addr(deployerPrivateKey));

        IController controller = IController(UnrealLib.runDeploy(true));

        Factory factory = Factory(controller.factory());

        // deploy IFO harvester
        factory.deployIfoHarvester(
            UnrealLib.LIQUID_BOX_DAI_USDC, UnrealLib.ALM_GAUGE_DAI_USDC, "IFO Harvester DAI-USDC", "ifoTDT-DAI-USDC"
        );

        // deploy compounder + harvester
        CompounderVault compounderVault =
            CompounderVault(factory.deployCompounder(UnrealLib.TOKEN_CVR, "Compounder CVR", "cCVR"));
        factory.deployHarvester(
            UnrealLib.LIQUID_BOX_DAI_USDC,
            UnrealLib.ALM_GAUGE_DAI_USDC,
            "Harvester DAI-USDC",
            "xTDT-DAI-USDC",
            address(compounderVault)
        );

        vm.stopBroadcast();
    }

    function testDeployPolygon() external {}
}
