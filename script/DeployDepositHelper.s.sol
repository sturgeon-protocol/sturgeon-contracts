// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/DepositHelper.sol";

contract DeployDepositHelper is Script {
    function run() external {
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new DepositHelper();
        vm.stopBroadcast();
    }

    function testDeploy_() external {}
}
