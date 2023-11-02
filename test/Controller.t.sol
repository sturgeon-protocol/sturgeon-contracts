// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Controller} from "../src/Controller.sol";

contract ControllerTest is Test {
    Controller public controller;

    function setUp() public {
        controller = new Controller(address(this));
    }

    function test_init() public {
        assertEq(controller.governance(), address(this));
        assertEq(controller.isOperator(address(this)), true);
        vm.expectRevert();
        vm.prank(address(1));
        controller.registerOperator(address(2));
        controller.registerOperator(address(2));
        assertEq(controller.isOperator(address(2)), true);
        assertEq(controller.operatorsList().length, 2);
        controller.removeOperator(address(2));
        assertEq(controller.operatorsList().length, 1);

        controller.registerVault(address(3));
        assertEq(controller.vaultsListLength(), 1);
        assertEq(controller.vaultsList().length, 1);
        assertEq(controller.vaults(0), address(3));
        assertEq(controller.isValidVault(address(3)), true);
        controller.removeVault(address(3));
        assertEq(controller.vaultsList().length, 0);
        assertEq(controller.isValidVault(address(3)), false);
    }
}
