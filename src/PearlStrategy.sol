// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "./base/StrategyStrictBase.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IGaugeV2ALM.sol";
import "./interfaces/IController.sol";
import "./interfaces/IIFO.sol";
import "./interfaces/IGauge.sol";
import "./interfaces/ITetuLiquidator.sol";
import "./interfaces/IVeDistributor.sol";

/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.°:°•.°+.*•´.*:*.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*/
/*                                 Pearl strategy                                       */
/* Contract for taking care of all necessary actions for the underlying token such us:  */
/* Rewards utilization via Liquidator                                                   */
/* Compounding - creating more underlying                                               */
/* Sending profit to different destinations                                             */
/* Have rewards/compounding logic, depending on setup case                              */
/* Compounding should be called no more frequently than 1 per 12h                       */
/*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.°:°•.°+.*•´.*:*.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*/

contract PearlStrategy is StrategyStrictBase {
    using SafeERC20 for IERC20;

    uint internal constant LIQUIDATOR_PRICE_IMPACT_TOLERANCE = 20_000;

    uint public lastHardWork;

    address public gauge;

    address public gaugeRewardToken;

    bool public ifo;

    address public compounder;

    uint public minHardWorkDelay = 12 hours;

    error WaitTill(uint timestamp);

    constructor(address vault_, address gauge_, bool ifo_, address compounder_) StrategyStrictBase(vault_) {
        gauge = gauge_;
        ifo = ifo_;
        compounder = compounder_;
        IERC20(asset).approve(gauge_, type(uint).max);
        IController controller = IController(IVault(vault).controller());
        address _gaugeRewardToken = IGaugeV2ALM(gauge_).rewardToken();
        gaugeRewardToken = _gaugeRewardToken;
        if (ifo) {
            IERC20(_gaugeRewardToken).approve(controller.ifo(), type(uint).max);
            IERC20(controller.stgn()).approve(controller.multigauge(), type(uint).max);
        } else {
            IERC20(_gaugeRewardToken).approve(controller.liquidator(), type(uint).max);
            address compounderAsset = IERC4626(compounder_).asset();
            IERC20(compounderAsset).approve(compounder_, type(uint).max);
            IERC20(compounder_).approve(controller.multigauge(), type(uint).max);
        }
        lastHardWork = block.timestamp;
    }

    function setMinHardWorkDelay(uint delay) external {
        if (msg.sender != IController(IVault(vault).controller()).governance()) {
            revert("Denied");
        }
        minHardWorkDelay = delay;
    }

    function doHardWork() external {
        // claim fees if available
        // liquidate fee if available

        uint timelock = lastHardWork + minHardWorkDelay;
        if (block.timestamp < timelock) {
            revert WaitTill(timelock);
        }

        uint rtReward = _claim();
        uint perfFee = rtReward / 10;
        uint veDistFee = perfFee / 2;
        rtReward -= perfFee;
        IERC20 rt = IERC20(gaugeRewardToken);

        IController controller = IController(IVault(vault).controller());
        IVeDistributor veDist = IVeDistributor(controller.veDistributor());
        rt.safeTransfer(address(veDist), veDistFee);
        veDist.checkpoint();
        rt.safeTransfer(controller.perfFeeTreasury(), perfFee - veDistFee);

        IGauge multigauge = IGauge(controller.multigauge());
        if (ifo) {
            IIFO _ifo = IIFO(controller.ifo());
            (bool exchanged, uint got) = _ifo.exchange(rtReward);
            if (exchanged && got > 0) {
                multigauge.notifyRewardAmount(vault, controller.stgn(), got);
            }
        } else {
            address _compounder = compounder;
            ITetuLiquidator l = ITetuLiquidator(controller.liquidator());
            address asset = IERC4626(_compounder).asset();
            uint b = IERC20(asset).balanceOf(address(this));
            l.liquidate(gaugeRewardToken, asset, rtReward, LIQUIDATOR_PRICE_IMPACT_TOLERANCE);
            uint got = IERC20(asset).balanceOf(address(this)) - b;
            if (got > 0) {
                uint shares = IERC4626(_compounder).deposit(got, address(this));
                multigauge.notifyRewardAmount(vault, _compounder, shares);
            }
        }

        lastHardWork = block.timestamp;
    }

    function isReadyToHardWork() external view returns (bool) {
        return block.timestamp > lastHardWork + minHardWorkDelay && IGaugeV2ALM(gauge).earnedReward(address(this)) > 0;
    }

    function investedAssets() public view override returns (uint) {
        return IGaugeV2ALM(gauge).balanceOf(address(this));
    }

    function _claim() internal override returns (uint rtReward) {
        IERC20 rt = IERC20(gaugeRewardToken);
        uint oldBal = rt.balanceOf(address(this));
        IGaugeV2ALM(gauge).collectReward();
        rtReward = rt.balanceOf(address(this)) - oldBal;
    }

    function _depositToPool(uint amount) internal override {
        IGaugeV2ALM(gauge).deposit(amount);
    }

    function _emergencyExitFromPool() internal override {
        _withdrawAllFromPool();
        IERC20(asset).safeTransfer(vault, IERC20(asset).balanceOf(address(this)));
    }

    function _withdrawFromPool(uint amount) internal override {
        IGaugeV2ALM(gauge).withdraw(amount);
        IERC20(asset).safeTransfer(vault, amount);
    }

    function _withdrawAllFromPool() internal override {
        _withdrawFromPool(IGaugeV2ALM(gauge).balanceOf(address(this)));
    }
}
