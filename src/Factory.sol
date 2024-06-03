// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "./base/Controllable.sol";
import "./CompounderVault.sol";
import "./PearlStrategy.sol";
import "./interfaces/IMultiPool.sol";
import "./lib/DeployerLib.sol";

contract Factory is Controllable {
    string public constant VERSION = "1.0.0";

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
        vault = DeployerLib.deployHarvesterVault(_controller, underlying, vaultName, vaultSymbol);
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
        IController(controller()).registerVault(compounder, false);
    }

    function deployHarvester(
        address underlying,
        address pearlGauge,
        string calldata vaultName,
        string calldata vaultSymbol,
        address compounderVault
    ) external onlyGovernance returns (address vault, address strategy) {
        address _controller = controller();
        vault = DeployerLib.deployHarvesterVault(_controller, underlying, vaultName, vaultSymbol);
        strategy = address(new PearlStrategy(vault, pearlGauge, false, compounderVault));
        IVault(vault).setStrategy(strategy);
        address multigauge = IController(_controller).multigauge();
        IGauge(multigauge).addStakingToken(vault);
        IMultiPool(multigauge).registerRewardToken(vault, compounderVault);
        IController(_controller).registerVault(vault, true);
    }

    function _requireGovernance() internal view {
        require(isGovernance(msg.sender), "Denied");
    }
}
