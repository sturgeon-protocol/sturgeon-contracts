// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./base/StrategyStrictBase.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IPearlGaugeV2.sol";
import "./interfaces/IController.sol";
import "./interfaces/IIFO.sol";
import "./interfaces/IGauge.sol";

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
    using SafeERC20 for IERC20;

    uint public lastHardWork;

    address public gauge;

    bool public harvester;

    constructor(address vault_, address gauge_, bool harvester_) StrategyStrictBase(vault_) {
        vault = vault_;
        asset = IVault(vault_).asset();
        gauge = gauge_;
        harvester = harvester_;
        IERC20(asset).approve(gauge_, type(uint).max);
    }

    function isReadyToHardWork() external view returns (bool) {
        return IPearlGaugeV2(gauge).earned(address(this)) > 0;
    }

    function doHardWork() external /* returns (uint earned, uint lost)*/ {
        // claim fees if available
        // liquidate fee if available

        uint rtReward = _claim();

        IController controller = IController(IVault(vault).controller());

        if (harvester) {
            IIFO ifo = IIFO(controller.ifo());
            IGauge multigauge = IGauge(controller.multigauge());
            (bool exchanged, uint got) = ifo.exchange(rtReward);
            if (exchanged) {
                multigauge.notifyRewardAmount(vault, controller.stgn(), got);
            } else {
                multigauge.notifyRewardAmount(vault, IPearlGaugeV2(gauge).rewardToken(), rtReward);
            }
        } else {
            // todo Compounder CVR
        }
    }

    function investedAssets() public view override returns (uint) {
        return IPearlGaugeV2(gauge).balanceOf(address(this));
    }

    function _claim() internal override returns (uint rtReward) {
        IPearlGaugeV2 _gauge = IPearlGaugeV2(gauge);
        IERC20 rt = IERC20(_gauge.rewardToken());
        uint oldBal = rt.balanceOf(address(this));
        IPearlGaugeV2(gauge).getReward();
        rtReward = rt.balanceOf(address(this)) - oldBal;
    }

    function _depositToPool(uint amount) internal override {
        IPearlGaugeV2(gauge).deposit(amount);
    }

    function _emergencyExitFromPool() internal override {
        _withdrawAllFromPool();
        IERC20(asset).safeTransfer(vault, IERC20(asset).balanceOf(address(this)));
    }

    function _withdrawFromPool(uint amount) internal override {
        IPearlGaugeV2(gauge).withdraw(amount);
        IERC20(asset).safeTransfer(vault, amount);
    }

    function _withdrawAllFromPool() internal override {
        _withdrawFromPool(IPearlGaugeV2(gauge).balanceOf(address(this)));
    }
}
