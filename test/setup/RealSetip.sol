// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Controller.sol";
import "../../chains/RealLib.sol";

abstract contract RealSetup is Test {
    // Trident USTB-PEARL
    address internal ALM = 0xa77cb64Ee2ecF17D735a3b1b9820131E41758b50;

    // Gauge for ALM
    address internal GAUGE_ALM = 0x3C485daDcB645fD30047848b94B8eBEA5f8BD843;

    Controller public controller;
    Factory public factory;
    address public tokenA = ALM;
    address public tokenC = RealLib.TOKEN_PEARL;
    address public tokenD = RealLib.TOKEN_CVR;
    IGaugeV2ALM public pearlGauge = IGaugeV2ALM(GAUGE_ALM);

    constructor() {
        vm.selectFork(vm.createFork(vm.envString("REAL_RPC_URL")));
        vm.rollFork(82383);

        controller = Controller(RealLib.runDeploy(false));
        factory = Factory(controller.factory());
    }
}
