// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "../../src/base/StrategyStrictBase.sol";
import "../../src/interfaces/IVault.sol";

contract MockStrategy is StrategyStrictBase {
    uint public lastHardWork;
    address public pool;

    constructor(address vault_, address pool_) StrategyStrictBase(vault_) {
        vault = vault_;
        asset = IVault(vault_).asset();
        pool = pool_;
    }

    function isReadyToHardWork() external pure returns (bool) {
        // todo
        return true;
    }

    function doHardWork() external /* returns (uint earned, uint lost)*/ {}

    function investedAssets() public view override returns (uint) {}

    function _claim() internal virtual override returns (uint rtReward) {}

    function _depositToPool(uint amount) internal override {}

    function _emergencyExitFromPool() internal override {}

    function _withdrawFromPool(uint amount) internal override /* returns (uint investedAssetsUSD, uint assetPrice)*/ {}

    function _withdrawAllFromPool() internal override /* returns (uint investedAssetsUSD, uint assetPrice)*/ {}
}
