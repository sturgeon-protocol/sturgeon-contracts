// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {RealLib} from "../chains/RealLib.sol";

contract DeployReal is Script {
    function run() external {
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        RealLib.runDeploy(true);
        vm.stopBroadcast();
    }

    function testDeployChain() external {}
}
