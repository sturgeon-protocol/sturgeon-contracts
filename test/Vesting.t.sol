// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./setup/MockSetup.sol";

contract VestingTest is MockSetup {
    function test_vesting() public {
        address[] memory vesting = ISTGN(controller.stgn()).vesting();
        for (uint i; i < vesting.length; ++i) {
            Vesting _vesting = Vesting(vesting[i]);
            _vesting.start(IERC20(_vesting.token()).balanceOf(address(_vesting)));

            vm.expectRevert("Not claimant");
            _vesting.claim();

            vm.startPrank(_vesting.claimant());
            skip(1 days);
            vm.expectRevert("Too early");
            _vesting.claim();
            skip(30 days);
            _vesting.claim();
            vm.stopPrank();
        }
    }
}
