// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/Frontend.sol";

contract DeployFrontendGoerli is Script {
    function run() external {
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new Frontend(0x8216C9afFC982428aF33D1D9F165bAf9D75AebBa);
        vm.stopBroadcast();
    }

    function testDeployFrontendTestnet() external {}
}
