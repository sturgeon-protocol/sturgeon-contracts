// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./base/Controllable.sol";
import "./HarvesterVault.sol";
import "./CompounderVault.sol";
import "./PearlStrategy.sol";
import "./interfaces/IMultiPool.sol";

contract Factory is Controllable {
    function init(address controller_) external initializer {
        __Controllable_init(controller_);
    }

    modifier onlyGovernance() {
        _requireGovernance();
        _;
    }

    function deployIfoHarvester(
        address underlying,
        address pearlGauge,
        string calldata vaultName,
        string calldata vaultSymbol
    ) external onlyGovernance returns (address vault, address strategy) {
        address _controller = controller();
        vault = address(new HarvesterVault(_controller, IERC20(underlying), vaultName, vaultSymbol, 4_000));
        strategy = address(new PearlStrategy(vault, pearlGauge, true, address(0)));
        IVault(vault).setStrategy(strategy);
        IGauge(IController(_controller).multigauge()).addStakingToken(vault);
        IController(_controller).registerVault(vault, true);
    }

    function deployCompounder(
        address underlying,
        string calldata vaultName,
        string calldata vaultSymbol
    ) external onlyGovernance returns (address compounder) {
        compounder = address(new CompounderVault(IERC20(underlying), vaultName, vaultSymbol));
    }

    function deployHarvester(
        address underlying,
        address pearlGauge,
        string calldata vaultName,
        string calldata vaultSymbol,
        address compounderVault
    ) external onlyGovernance returns (address vault, address strategy) {
        address _controller = controller();
        vault = address(new HarvesterVault(_controller, IERC20(underlying), vaultName, vaultSymbol, 4_000));
        strategy = address(new PearlStrategy(vault, pearlGauge, false, compounderVault));
        IVault(vault).setStrategy(strategy);
        address multigauge = IController(_controller).multigauge();
        IGauge(multigauge).addStakingToken(vault);
        IMultiPool(multigauge).registerRewardToken(vault, compounderVault);
    }

    function _requireGovernance() internal view {
        require(isGovernance(msg.sender), "Denied");
    }
}
