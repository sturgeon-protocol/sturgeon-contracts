// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {Compounder} from "../src/Compounder.sol";
import {ControllableProxy} from "../src/ControllableProxy.sol";

contract DeployCompounderReal is Script {
    address internal constant CONTROLLER = 0xE0E71B484Bb20E37d18Ab51fB60c32deC778478A;

    function run() external {
        uint deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ControllableProxy proxy = new ControllableProxy();
        address impl = address(new Compounder());
        proxy.initProxy(impl);
        Compounder compounder = Compounder(address(proxy));
        compounder.init(CONTROLLER);

        vm.stopBroadcast();
    }

    function testDeployHelpersReal() external {}
}
