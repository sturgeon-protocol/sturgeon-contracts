// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./setup/MockSetup.sol";
import "../src/HarvesterVault.sol";
import "../src/PearlStrategy.sol";
import "../src/CompounderVault.sol";
import "../src/Compounder.sol";

contract PearlStrategyTest is MockSetup {
    function test_ifo() public {
        HarvesterVault vault = new HarvesterVault(address(controller), IERC20(tokenA), "IFO Harvester MOCK_A", "xTokenA", 4_000);
        PearlStrategy strategy = new PearlStrategy(address(vault), address(pearlGauge), true, address(0));
        vault.setStrategy(address(strategy));
        IGauge(controller.multigauge()).addStakingToken(address(vault));

        deal(tokenA, address(this), 1e20);
        IERC20(tokenA).approve(address(vault), 1e20);
        vault.mint(1e18, address(this));
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(IMultiPool(controller.multigauge()).balanceOf(address(vault), address(this)), 1e18);
        vault.redeem(1e18, address(this), address(this));
        assertEq(vault.balanceOf(address(this)), 0);

        vault.deposit(1e18, address(this));
        assertEq(vault.balanceOf(address(this)), 1e18);

        skip(3600);

        vm.expectRevert("Not valid vault");
        strategy.doHardWork();

        controller.registerVault(address(vault), true);
        strategy.doHardWork();

        deal(tokenC, address(pearlGauge), 1e18);
        skip(3600);

        strategy.doHardWork();

        assertEq(_getStgnRewardFromIfoGauge(address(vault)), 0);

        skip(360000);

        assertGt(_getStgnRewardFromIfoGauge(address(vault)), 0);
    }

    function test_compounder() public {
        HarvesterVault vault = new HarvesterVault(address(controller), IERC20(tokenA), "Harvester MOCK_A", "xTokenA", 4_000);

        CompounderVault compounderVault = new CompounderVault(IERC20(address(vault)), "Compounder vault for xTokenA", "xxTokenA");

        PearlStrategy strategy = new PearlStrategy(address(vault), address(pearlGauge), false, address(compounderVault));
        vault.setStrategy(address(strategy));

        IGauge(controller.multigauge()).addStakingToken(address(vault));

        deal(tokenA, address(this), 1e20);
        IERC20(tokenA).approve(address(vault), 1e20);
        vault.mint(1e18, address(this));
        assertEq(vault.balanceOf(address(this)), 1e18);

        strategy.doHardWork();

    }

    function _getStgnRewardFromIfoGauge(address vault) internal returns (uint claimedStgn) {
        uint b = IERC20(controller.stgn()).balanceOf(address(this));
        IGauge(controller.multigauge()).getAllRewards(vault, address(this));
        uint bNew = IERC20(controller.stgn()).balanceOf(address(this));
        return bNew - b;
    }
}
