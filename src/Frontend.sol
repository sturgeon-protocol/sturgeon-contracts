// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./interfaces/IController.sol";
import "./interfaces/IVault.sol";
import "./PearlStrategy.sol";
import "./interfaces/IMultiPool.sol";
import "./base/StakelessMultiPoolBase.sol";
import "./interfaces/ILiquidBox.sol";

contract Frontend {
    IController public controller;

    struct LocalVars {
        address[] harvesters;
        address[] compounders;
        uint harvestersLen;
        uint compoundersLen;
        uint totalLen;
        address stgn;
        StakelessMultiPoolBase gauge;
    }

    constructor(address controller_) {
        controller = IController(controller_);
    }

    function getLiquidBoxSharePrice(address alm, address priceToken) public view returns(uint price) {
        ITetuLiquidator liquidator = ITetuLiquidator(controller.liquidator());
        ILiquidBox lb = ILiquidBox(alm);
        address token0 = lb.token0();
        address token1 = lb.token1();
        (uint total0, uint total1,) = lb.getTotalAmounts();
        uint total0Priced;
        uint total1Priced;
        if (token0 != priceToken) {
            uint decimals = IERC20Metadata(token0).decimals();
            total0Priced = liquidator.getPrice(token0, priceToken, 10 ** decimals) * total0 / 10 ** decimals;
        } else {
            total0Priced = total0;
        }
        if (token1 != priceToken) {
            uint decimals = IERC20Metadata(token1).decimals();
            total1Priced = liquidator.getPrice(token1, priceToken, 10 ** decimals) * total1 / 10 ** decimals;
        } else {
            total1Priced = total0;
        }
        price = (total0Priced + total1Priced) * 1e18 / lb.totalSupply();
    }

    function allVaults(address user)
        external
        view
        returns (
            address[] memory vaults,
            address[] memory compounders,
            address[] memory underlyings,
            string[6][] memory strings, // vault name, vault symbol, compounder name, compounder symbol, underlying name, underlying symbol
            address[] memory strategies,
            uint[] memory tvls,
            uint[] memory decimals,
            uint[2][] memory balances, // vault user balance, underlying user balance
            uint[3][] memory gaugeLeft // left, periodFinish, earned
        )
    {
        LocalVars memory v;
        v.gauge = StakelessMultiPoolBase(controller.multigauge());
        v.stgn = controller.stgn();
        v.harvesters = controller.harvesterVaultsList();
        v.compounders = controller.compounderVaultsList();
        v.harvestersLen = v.harvesters.length;
        v.compoundersLen = v.compounders.length;
        v.totalLen = v.harvestersLen + v.compoundersLen;
        vaults = new address[](v.totalLen);
        compounders = new address[](v.totalLen);
        underlyings = new address[](v.totalLen);
        strategies = new address[](v.totalLen);
        strings = new string[6][](v.totalLen);
        tvls = new uint[](v.totalLen);
        decimals = new uint[](v.totalLen);
        balances = new uint[2][](v.totalLen);
        gaugeLeft = new uint[3][](v.totalLen);
        for (uint i; i < v.harvestersLen; ++i) {
            vaults[i] = v.harvesters[i];
            underlyings[i] = IERC4626(vaults[i]).asset();
            strategies[i] = address(IVault(vaults[i]).strategy());
            compounders[i] = PearlStrategy(strategies[i]).compounder();
            tvls[i] = IERC4626(vaults[i]).totalAssets();
            decimals[i] = IERC20Metadata(vaults[i]).decimals();
            strings[i][0] = IERC20Metadata(vaults[i]).name();
            strings[i][1] = IERC20Metadata(vaults[i]).symbol();
            strings[i][4] = IERC20Metadata(underlyings[i]).name();
            strings[i][5] = IERC20Metadata(underlyings[i]).symbol();

            if (compounders[i] != address(0)) {
                strings[i][2] = IERC20Metadata(compounders[i]).name();
                strings[i][3] = IERC20Metadata(compounders[i]).symbol();
                gaugeLeft[i][0] = v.gauge.left(vaults[i], compounders[i]);
                gaugeLeft[i][1] = v.gauge.periodFinish(vaults[i], compounders[i]);
                if (user != address(0)) {
                    gaugeLeft[i][2] = v.gauge.earned(vaults[i], compounders[i], user);
                }
            } else {
                gaugeLeft[i][0] = v.gauge.left(vaults[i], v.stgn);
                gaugeLeft[i][1] = v.gauge.periodFinish(vaults[i], v.stgn);
                if (user != address(0)) {
                    gaugeLeft[i][2] = v.gauge.earned(vaults[i], v.stgn, user);
                }
            }
        }

        if (user != address(0)) {
            for (uint i; i < v.harvestersLen; ++i) {
                balances[i][0] = IERC20(vaults[i]).balanceOf(user);
                balances[i][1] = IERC20(underlyings[i]).balanceOf(user);
            }
        }

        uint k;
        for (uint i = v.harvestersLen; i < v.totalLen; ++i) {
            vaults[i] = v.compounders[k];
            underlyings[i] = IERC4626(vaults[i]).asset();
            tvls[i] = IERC4626(vaults[i]).totalAssets();
            decimals[i] = IERC20Metadata(vaults[i]).decimals();
            strings[i][0] = IERC20Metadata(vaults[i]).name();
            strings[i][1] = IERC20Metadata(vaults[i]).symbol();
            strings[i][4] = IERC20Metadata(underlyings[i]).name();
            strings[i][5] = IERC20Metadata(underlyings[i]).symbol();
            ++k;
        }

        if (user != address(0)) {
            for (uint i = v.harvestersLen; i < v.totalLen; ++i) {
                balances[i][0] = IERC20(vaults[i]).balanceOf(user);
                balances[i][1] = IERC20(underlyings[i]).balanceOf(user);
            }
        }
    }
}
