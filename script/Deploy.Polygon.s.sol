// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../chains/PolygonLib.sol";

contract DeployPolygon is Script {
    function run() external {
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        PolygonLib.runDeploy(true);
        vm.stopBroadcast();
    }

    function testDeployPolygon() external {}
}
