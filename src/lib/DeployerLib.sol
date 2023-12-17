// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "../HarvesterVault.sol";

library DeployerLib {
    function deployHarvesterVault(
        address controller,
        address underlying,
        string calldata vaultName,
        string calldata vaultSymbol
    ) external returns (address) {
        return address(new HarvesterVault(controller, IERC20(underlying), vaultName, vaultSymbol, 4_000));
    }
}
