// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./base/StrategyStrictBase.sol";
import "./interfaces/IVault.sol";

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.°:°•.°+.*•´.*:*.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*/
/*                                 Pearl strategy                                       */
/* Contract for taking care of all necessary actions for the underlying token such us:  */
/* Rewards utilization via Liquidator                                                   */
/* Compounding - creating more underlying                                               */
/* Sending profit to different destinations                                             */
/* Have rewards/compounding logic, depending on setup case                              */
/* Strategy should send gas compensation on every compounding                           */
/* Compensation will be taken from user part of profit but no more than 10%             */
/* Compounding should be called no more frequently than 1 per 12h                       */
/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.°:°•.°+.*•´.*:*.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*/

contract PearlStrategy is StrategyStrictBase {

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

    function doHardWork() external returns (uint earned, uint lost) {}


    function investedAssets() public view override returns (uint) {

    }

    function _claim() internal override {

    }

    function _depositToPool(uint amount) internal override {

    }

    function _emergencyExitFromPool() internal override {}

    function _withdrawFromPool(uint amount) internal override returns (uint investedAssetsUSD, uint assetPrice) {

    }

    function _withdrawAllFromPool() internal override returns (uint investedAssetsUSD, uint assetPrice) {

    }
}
