// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {Controller} from "../src/Controller.sol";
import "./setup/MockSetup.sol";

contract ControllerTest is Test, MockSetup {
    function setUp() public {}

    function test_init() public {
        controller = _init();

        assertEq(controller.governance(), address(this));
        assertEq(controller.isOperator(address(this)), true);
        vm.expectRevert();
        vm.prank(address(1));
        controller.registerOperator(address(2));
        controller.registerOperator(address(2));
        assertEq(controller.isOperator(address(2)), true);
        assertEq(controller.operatorsList().length, 3);
        controller.removeOperator(address(2));
        assertEq(controller.operatorsList().length, 2);

        controller.registerVault(address(3), true);
        assertEq(controller.harvesterVaultsListLength(), 1);
        assertEq(controller.harvesterVaultsList().length, 1);
        assertEq(controller.harvesterVaults(0), address(3));
        assertEq(controller.isValidVault(address(3)), true);
        controller.removeVault(address(3), true);
        assertEq(controller.harvesterVaultsList().length, 0);
        assertEq(controller.isValidVault(address(3)), false);
    }
}
