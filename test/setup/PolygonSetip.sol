// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Controller.sol";
import "../../chains/PolygonLib.sol";

abstract contract PolygonSetup is Test {
    Controller public controller;

    constructor() {
        PolygonLib.runDeploy(true);
    }
}
