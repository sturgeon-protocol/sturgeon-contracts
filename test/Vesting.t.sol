// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./setup/MockSetup.sol";


contract VestingTest is MockSetup {
    function test_vesting() public {
        Vesting vesting = Vesting(controller.vesting());
        vesting.start(IERC20(vesting.token()).balanceOf(address(vesting)));
        skip(1 days);
        vm.expectRevert("Too early");
        vesting.claim();
        skip(30 days);
        vesting.claim();
    }
}
