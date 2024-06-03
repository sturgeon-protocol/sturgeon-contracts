// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import "../interfaces/IStrategyStrict.sol";

/// @title Abstract contract for base strict strategy functionality
/// @author AlehNat
abstract contract StrategyStrictBase is IStrategyStrict {
    using SafeERC20 for IERC20;

    // *************************************************************
    //                        CONSTANTS
    // *************************************************************

    // *************************************************************
    //                        ERRORS
    // *************************************************************

    string internal constant WRONG_CONTROLLER = "SB: Wrong controller";
    string internal constant DENIED = "SB: Denied";
    string internal constant TOO_HIGH = "SB: Too high";
    string internal constant IMPACT_TOO_HIGH = "SB: Impact too high";
    string internal constant WRONG_AMOUNT = "SB: Wrong amount";
    string internal constant ALREADY_INITIALIZED = "SB: Already initialized";

    // *************************************************************
    //                        VARIABLES
    //                Keep names and ordering!
    //                 Add only in the bottom.
    // *************************************************************

    /// @dev Underlying asset
    address public override asset;
    /// @dev Linked vault
    address public override vault;
    /// @dev Percent of profit for autocompound inside this strategy.
    uint public override compoundRatio;

    // *************************************************************
    //                        EVENTS
    // *************************************************************

    event WithdrawAllToVault(uint amount);
    event WithdrawToVault(uint amount, uint sent, uint balance);
    event EmergencyExit(address sender, uint amount);
    event ManualClaim(address sender);
    event InvestAll(uint balance);
    event DepositToPool(uint amount);
    event WithdrawFromPool(uint amount);
    event WithdrawAllFromPool(uint amount);
    event Claimed(address token, uint amount);
    event CompoundRatioChanged(uint oldValue, uint newValue);

    // *************************************************************
    //                        INIT
    // *************************************************************

    constructor(address vault_) {
        asset = IERC4626(vault_).asset();
        vault = vault_;
    }

    // *************************************************************
    //                        VIEWS
    // *************************************************************

    /// @dev Total amount of underlying assets under control of this strategy.
    function totalAssets() public view override returns (uint) {
        return IERC20(asset).balanceOf(address(this)) + investedAssets();
    }

    // *************************************************************
    //                    DEPOSIT/WITHDRAW
    // *************************************************************

    /// @dev Stakes everything the strategy holds into the reward pool.
    function investAll() external override {
        require(msg.sender == vault, DENIED);
        address _asset = asset; // gas saving
        uint balance = IERC20(_asset).balanceOf(address(this));
        if (balance > 0) {
            _depositToPool(balance);
        }
        emit InvestAll(balance);
    }

    /// @dev Withdraws all underlying assets to the vault
    function withdrawAllToVault() external override {
        address _vault = vault;
        address _asset = asset; // gas saving
        require(msg.sender == _vault, DENIED);
        _withdrawAllFromPool();
        uint balance = IERC20(_asset).balanceOf(address(this));

        if (balance != 0) {
            IERC20(_asset).safeTransfer(_vault, balance);
        }
        emit WithdrawAllToVault(balance);
    }

    /// @dev Withdraws some assets to the vault
    function withdrawToVault(uint amount) external override {
        address _vault = vault;
        address _asset = asset; // gas saving
        require(msg.sender == _vault, DENIED);
        uint balance = IERC20(_asset).balanceOf(address(this));
        if (amount > balance) {
            _withdrawFromPool(amount - balance);
            balance = IERC20(_asset).balanceOf(address(this));
        }

        uint amountAdjusted = Math.min(amount, balance);
        if (amountAdjusted != 0) {
            IERC20(_asset).safeTransfer(_vault, amountAdjusted);
        }
        emit WithdrawToVault(amount, amountAdjusted, balance);
    }

    // *************************************************************
    //                       VIRTUAL
    // These functions must be implemented in the strategy contract
    // *************************************************************

    /// @dev Amount of underlying assets invested to the pool.
    function investedAssets() public view virtual returns (uint);

    /// @dev Deposit given amount to the pool.
    function _depositToPool(uint amount) internal virtual;

    /// @dev Withdraw given amount from the pool.
    //return investedAssetsUSD Sum of USD value of each asset in the pool that was withdrawn, decimals of {asset}.
    //return assetPrice Price of the strategy {asset}.
    function _withdrawFromPool(uint amount) internal virtual; /* returns (uint investedAssetsUSD, uint assetPrice)*/

    /// @dev Withdraw all from the pool.
    //return investedAssetsUSD Sum of USD value of each asset in the pool that was withdrawn, decimals of {asset}.
    //return assetPrice Price of the strategy {asset}.
    function _withdrawAllFromPool() internal virtual; /* returns (uint investedAssetsUSD, uint assetPrice)*/

    /// @dev If pool support emergency withdraw need to call it for emergencyExit()
    ///      Withdraw assets without impact checking.
    function _emergencyExitFromPool() internal virtual;

    /// @dev Claim all possible rewards.
    function _claim() internal virtual returns (uint rtReward);
}
