// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./base/StrategyStrictBase.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IPearlGaugeV2.sol";
import "./interfaces/IController.sol";
import "./interfaces/IIFO.sol";
import "./interfaces/IGauge.sol";
import "./interfaces/ITetuLiquidator.sol";

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

    address public gaugeRewardToken;

    bool public ifo;

    address public compounder;

    constructor(address vault_, address gauge_, bool ifo_, address compounder_) StrategyStrictBase(vault_) {
        vault = vault_;
        asset = IVault(vault_).asset();
        gauge = gauge_;
        ifo = ifo_;
        compounder = compounder_;
        IERC20(asset).approve(gauge_, type(uint).max);
        address _gaugeRewardToken = IPearlGaugeV2(gauge_).rewardToken();
        gaugeRewardToken = _gaugeRewardToken;
        if (ifo) {
            IController controller = IController(IVault(vault).controller());
            IERC20(_gaugeRewardToken).approve(controller.ifo(), type(uint).max);
            IERC20(controller.stgn()).approve(controller.multigauge(), type(uint).max);
        }
    }

    function isReadyToHardWork() external view returns (bool) {
        return IPearlGaugeV2(gauge).earned(address(this)) > 0;
    }

    function doHardWork() external /* returns (uint earned, uint lost)*/ {
        // claim fees if available
        // liquidate fee if available

        uint rtReward = _claim();

        IController controller = IController(IVault(vault).controller());

        IGauge multigauge = IGauge(controller.multigauge());
        if (ifo) {
            IIFO _ifo = IIFO(controller.ifo());
            (bool exchanged, uint got) = _ifo.exchange(rtReward);
            if (exchanged && got > 0) {
                multigauge.notifyRewardAmount(vault, controller.stgn(), got);
            }/* else {
                multigauge.notifyRewardAmount(vault, IPearlGaugeV2(gauge).rewardToken(), rtReward);
            }*/
        } else {
            ITetuLiquidator l = ITetuLiquidator(controller.liquidator());
            address asset = IERC4626(compounder).asset();
            uint b = IERC20(asset).balanceOf(address(this));
            l.liquidate(gaugeRewardToken, IERC4626(compounder).asset(), rtReward, 0);
            uint got = IERC20(asset).balanceOf(address(this)) - b;
            if (got > 0) {
                multigauge.notifyRewardAmount(vault, asset, got);
            }
        }
    }

    function investedAssets() public view override returns (uint) {
        return IPearlGaugeV2(gauge).balanceOf(address(this));
    }

    function _claim() internal override returns (uint rtReward) {
        IERC20 rt = IERC20(gaugeRewardToken);
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
