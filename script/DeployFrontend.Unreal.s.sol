// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/Frontend.sol";

contract DeployFrontendUnreal is Script {
    function run() external {
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new Frontend(0x4F69329E8dE13aA7EAc664368C5858AF6371FA4c);
        vm.stopBroadcast();
    }

    function testDeployFrontendTestnet() external {}
}
