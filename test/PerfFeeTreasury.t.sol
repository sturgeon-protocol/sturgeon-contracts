// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./setup/MockSetup.sol";

contract PerfFeeTreasuryTest is MockSetup {
    function testPerfFeeTreasury() public {
        (address v, address s) =
                            factory.deployIfoHarvester(tokenA, address(pearlGauge), "IFO Harvester MOCK_A", "xTokenA");
        IVault vault = IVault(v);
        IStrategyStrict strategy = IStrategyStrict(s);

        deal(tokenA, address(this), 1e20);
        IERC20(tokenA).approve(address(vault), 1e20);
        vault.mint(1e18, address(this));
        deal(tokenC, address(pearlGauge), 1e18);
        skip(3600);
        strategy.doHardWork();
        assertEq(_getRewardFromIfoGauge(address(vault), controller.stgn()), 0);

        PerfFeeTreasury pft = PerfFeeTreasury(controller.perfFeeTreasury());
        assertGt(IERC20(tokenC).balanceOf(address(pft)), 0);

        address[] memory tokens = new address[](1);
        tokens[0] = tokenC;
        vm.startPrank(address(911));
        vm.expectRevert("NOT_GOV");
        pft.claim(tokens);
        vm.stopPrank();

        pft.claim(tokens);

        address newOwner = address(0);
        vm.startPrank(address(911));
        vm.expectRevert("NOT_GOV");
        pft.offerOwnership(newOwner);
        vm.stopPrank();
        vm.expectRevert("ZERO_ADDRESS");
        pft.offerOwnership(newOwner);
        newOwner = address(2);
        pft.offerOwnership(newOwner);
        vm.expectRevert("NOT_GOV");
        pft.acceptOwnership();
        vm.prank(address(2));
        pft.acceptOwnership();
    }

    function _getRewardFromIfoGauge(address vault, address rewardTokenToCheck) internal returns (uint claimedRt) {
        uint b = IERC20(rewardTokenToCheck).balanceOf(address(this));
        IGauge(controller.multigauge()).getAllRewards(vault, address(this));
        uint bNew = IERC20(rewardTokenToCheck).balanceOf(address(this));
        return bNew - b;
    }
}
