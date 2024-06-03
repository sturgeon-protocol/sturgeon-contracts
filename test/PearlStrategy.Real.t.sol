// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "./setup/MockSetup.sol";
import "../src/HarvesterVault.sol";
import "../src/PearlStrategy.sol";
import "../src/CompounderVault.sol";
import "../src/Compounder.sol";
import "./setup/RealSetip.sol";
import {ILiquidatorController} from "../src/interfaces/ILiquidatorController.sol";

contract PearlStrategyRealTest is RealSetup {
    function test_ifo_real() public {
        HarvesterVault vault =
            new HarvesterVault(address(controller), IERC20(tokenA), "IFO Harvester MOCK_A", "xTokenA", 4_000);
        PearlStrategy strategy = new PearlStrategy(address(vault), address(pearlGauge), true, address(0));
        vault.setStrategy(address(strategy));
        vm.startPrank(RealLib.GOVERNANCE);
        IGauge(controller.multigauge()).addStakingToken(address(vault));
        vm.stopPrank();

        deal(tokenA, address(this), 1e20);
        IERC20(tokenA).approve(address(vault), 1e20);
        vault.mint(1e18, address(this));
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(IMultiPool(controller.multigauge()).balanceOf(address(vault), address(this)), 1e18);
        vault.redeem(1e18, address(this), address(this));
        assertEq(vault.balanceOf(address(this)), 0);

        uint depositAmount = 212000;
        vault.deposit(depositAmount, address(this));
        assertEq(vault.balanceOf(address(this)), depositAmount);

        skip(12 hours);

        vm.expectRevert("Not valid vault");
        strategy.doHardWork();

        vm.startPrank(RealLib.GOVERNANCE);
        controller.registerVault(address(vault), true);
        vm.stopPrank();

        strategy.doHardWork();

        skip(12 hours);

        strategy.doHardWork();

        assertLt(_getRewardFromIfoGauge(address(vault), controller.stgn()), 100);

        skip(12 hours);

        assertGt(_getRewardFromIfoGauge(address(vault), controller.stgn()), 0);

        // check logic
        vm.expectRevert(bytes("Denied"));
        strategy.setMinHardWorkDelay(1 hours);
        vm.prank(RealLib.GOVERNANCE);
        strategy.setMinHardWorkDelay(1 hours);
    }

    function test_factory_ifo_real() public {
        vm.startPrank(RealLib.GOVERNANCE);
        (address v, address s) =
            factory.deployIfoHarvester(tokenA, address(pearlGauge), "IFO Harvester MOCK_A", "xTokenA");
        vm.stopPrank();

        IVault vault = IVault(v);
        IStrategyStrict strategy = IStrategyStrict(s);

        deal(tokenA, address(this), 1e20);
        IERC20(tokenA).approve(address(vault), 1e20);
        vault.mint(1e18, address(this));
        assertEq(vault.balanceOf(address(this)), 1e18);
        assertEq(IMultiPool(controller.multigauge()).balanceOf(address(vault), address(this)), 1e18);
        vault.redeem(1e18, address(this), address(this));
        assertEq(vault.balanceOf(address(this)), 0, "1");

        uint depositAmount = 212000;
        vault.deposit(depositAmount, address(this));
        assertEq(vault.balanceOf(address(this)), depositAmount);
        skip(12 hours);
        strategy.doHardWork();
        skip(12 hours);
        strategy.doHardWork();
        assertLt(_getRewardFromIfoGauge(address(vault), controller.stgn()), 100, "2");
        skip(120 hours);
        assertGt(_getRewardFromIfoGauge(address(vault), controller.stgn()), 0, "3");
    }

    function _addRoute() internal {
        // add largest pool Pearl-CVR
        address liqGov = ILiquidatorController(ITetuLiquidator(RealLib.LIQUIDATOR).controller()).governance();
        vm.startPrank(liqGov);
        ITetuLiquidator.PoolData[] memory _pools = new ITetuLiquidator.PoolData[](1);
        _pools[0] = ITetuLiquidator.PoolData({
            pool: 0xfA88A4a7fF6D776c3D0A637095d7a9a4ed813872,
            swapper: 0x3C888C84511f4C0a4F3Ea5eD1a16ad7F6514077e,
            tokenIn: RealLib.TOKEN_PEARL,
            tokenOut: RealLib.TOKEN_CVR
        });
        ITetuLiquidator(RealLib.LIQUIDATOR).addLargestPools(_pools, false);
        vm.stopPrank();
    }

    function test_compounder_real() public {
        _addRoute();

        HarvesterVault vault =
            new HarvesterVault(address(controller), IERC20(tokenA), "Harvester MOCK_A", "xTokenA", 4_000);

        CompounderVault compounderVault =
            new CompounderVault(IERC20(tokenD), "Compounder vault for xTokenA", "xxTokenA");

        PearlStrategy strategy = new PearlStrategy(address(vault), address(pearlGauge), false, address(compounderVault));
        vault.setStrategy(address(strategy));

        vm.startPrank(RealLib.GOVERNANCE);
        IGauge(controller.multigauge()).addStakingToken(address(vault));
        IMultiPool(controller.multigauge()).registerRewardToken(address(vault), address(compounderVault));
        vm.stopPrank();

        deal(tokenA, address(this), 1e20);
        IERC20(tokenA).approve(address(vault), 1e20);
        vault.mint(1e18, address(this));
        assertEq(vault.balanceOf(address(this)), 1e18);

        skip(12 hours);

        strategy.doHardWork();

        assertEq(compounderVault.sharePrice(), 1e18);

        assertEq(_getRewardFromIfoGauge(address(vault), address(compounderVault)), 0);

        skip(120 hours);

        assertGt(_getRewardFromIfoGauge(address(vault), address(compounderVault)), 0);

        assertGt(compounderVault.balanceOf(address(this)), 0);

        compounderVault.withdrawAll();
    }

    function test_factory_compounder_real() public {
        _addRoute();
        vm.startPrank(RealLib.GOVERNANCE);
        CompounderVault compounderVault =
            CompounderVault(factory.deployCompounder(tokenD, "Compounder vault for xTokenA", "xxTokenA"));
        (address v, address s) = factory.deployHarvester(
            tokenA, address(pearlGauge), "Harvester MOCK_A", "xTokenA", address(compounderVault)
        );
        vm.stopPrank();
        IVault vault = IVault(v);
        IStrategyStrict strategy = IStrategyStrict(s);

        deal(tokenA, address(this), 1e20);
        IERC20(tokenA).approve(address(vault), 1e20);
        vault.mint(1e18, address(this));
        assertEq(vault.balanceOf(address(this)), 1e18);

        skip(12 hours);

        strategy.doHardWork();

        assertEq(compounderVault.sharePrice(), 1e18);

        assertEq(_getRewardFromIfoGauge(address(vault), address(compounderVault)), 0);

        skip(120 hours);

        assertGt(_getRewardFromIfoGauge(address(vault), address(compounderVault)), 0);

        assertGt(compounderVault.balanceOf(address(this)), 0);

        compounderVault.withdrawAll();
    }

    function _getRewardFromIfoGauge(address vault, address rewardTokenToCheck) internal returns (uint claimedRt) {
        uint b = IERC20(rewardTokenToCheck).balanceOf(address(this));
        IGauge(controller.multigauge()).getAllRewards(vault, address(this));
        uint bNew = IERC20(rewardTokenToCheck).balanceOf(address(this));
        return bNew - b;
    }
}
