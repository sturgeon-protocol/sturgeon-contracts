// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./interfaces/IController.sol";
import "./interfaces/IVault.sol";
import "./PearlStrategy.sol";
import "./interfaces/IMultiPool.sol";
import "./base/StakelessMultiPoolBase.sol";

contract Frontend {
    IController public controller;

    struct LocalVars {
        uint len;
        address stgn;
        StakelessMultiPoolBase gauge;
    }

    constructor(address controller_) {
        controller = IController(controller_);
    }

    function harvesters(address user)
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
        vaults = controller.harvesterVaultsList();
        v.stgn = controller.stgn();
        v.len = vaults.length;
        compounders = new address[](v.len);
        underlyings = new address[](v.len);
        strategies = new address[](v.len);
        strings = new string[6][](v.len);
        tvls = new uint[](v.len);
        decimals = new uint[](v.len);
        balances = new uint[2][](v.len);
        gaugeLeft = new uint[3][](v.len);
        for (uint i; i < v.len; ++i) {
            underlyings[i] = IERC4626(vaults[i]).asset();
            strategies[i] = address(IVault(vaults[i]).strategy());
            compounders[i] = PearlStrategy(strategies[i]).compounder();
            tvls[i] = IERC4626(vaults[i]).totalAssets();
            decimals[i] = IERC20Metadata(vaults[i]).decimals();

            // name and symbol
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
            for (uint i; i < v.len; ++i) {
                balances[i][0] = IERC20(vaults[i]).balanceOf(user);
                balances[i][1] = IERC20(underlyings[i]).balanceOf(user);
            }
        }
    }
}
