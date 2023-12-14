// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./setup/MockSetup.sol";
import "./mock/MockStrategy.sol";
import "../src/HarvesterVault.sol";

contract VaultTest is MockSetup {
    function test_vault() public {
        HarvesterVault vault =
            new HarvesterVault(address(controller), IERC20(tokenA), "Harvester vault for MOCK_A", "xTokenA", 4_000);
        MockStrategy strategy = new MockStrategy(address(vault), address(1));
        vault.setStrategy(address(strategy));
        IGauge(controller.multigauge()).addStakingToken(address(vault));

        deal(tokenA, address(this), 1e20);
        IERC20(tokenA).approve(address(vault), 1e20);
        vault.mint(1e18, address(this));
        assertEq(vault.balanceOf(address(this)), 1e18);
        vault.redeem(1e18, address(this), address(this));
        assertEq(vault.balanceOf(address(this)), 0);

        vault.deposit(1e18, address(this));
        assertEq(vault.balanceOf(address(this)), 1e18);
        vault.withdraw(1e18, address(this), address(this));
        assertEq(vault.balanceOf(address(this)), 0);

        vault.deposit(1e18, address(this));
        assertEq(vault.sharePrice(), 1e18);
        vault.withdrawAll();
        assertEq(vault.sharePrice(), 1e18);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.strategyAssets(), 0);
    }
}
