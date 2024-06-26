// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IStrategyStrict.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IController.sol";
import "./interfaces/IGauge.sol";

/// @title Harvester ERC4626 tokenized vault implementation
/// @author a17
contract HarvesterVault is ERC4626, ReentrancyGuard, IVault {
    using SafeERC20 for IERC20;
    using Math for uint;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Denominator for buffer calculation. 100% of the buffer amount.
    uint public constant BUFFER_DENOMINATOR = 100_000;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    address public controller;

    /// @inheritdoc IVault
    IStrategyStrict public strategy;

    /// @dev Percent of assets that will always stay in this vault.
    uint public immutable buffer;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      INITIALIZATION                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(
        address controller_,
        IERC20 asset_,
        string memory name_,
        string memory symbol_,
        uint buffer_
    ) ERC20(name_, symbol_) ERC4626(asset_) {
        // buffer is 5% max
        require(buffer_ <= BUFFER_DENOMINATOR / 20, "!BUFFER");
        buffer = buffer_;
        controller = controller_;
    }

    function setStrategy(address strategy_) external {
        require(address(strategy) == address(0), "Already");
        strategy = IStrategyStrict(strategy_);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         USER ACTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IERC4626
    function deposit(uint assets, address receiver) public override(ERC4626, IERC4626) nonReentrant returns (uint) {
        uint shares = super.deposit(assets, receiver);
        _afterDeposit(assets, shares, receiver);
        return shares;
    }

    /// @inheritdoc IERC4626
    function mint(uint shares, address receiver) public override(ERC4626, IERC4626) nonReentrant returns (uint) {
        uint assets = super.mint(shares, receiver);
        _afterDeposit(assets, shares, receiver);
        return assets;
    }

    /// @inheritdoc IERC4626
    function withdraw(
        uint assets,
        address receiver,
        address owner
    ) public override(ERC4626, IERC4626) nonReentrant returns (uint) {
        uint maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint shares = previewWithdraw(assets);

        _beforeWithdraw(assets, shares);

        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    /// @inheritdoc IERC4626
    function redeem(
        uint shares,
        address receiver,
        address owner
    ) public override(ERC4626, IERC4626) nonReentrant returns (uint) {
        uint maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint assets = previewRedeem(shares);

        require(assets != 0, "ZERO_ASSETS");
        _beforeWithdraw(assets, shares);

        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /// @dev Withdraw all available shares for tx sender.
    ///      The revert is expected if the balance is higher than `maxRedeem`
    ///      It suppose to be used only on UI - for on-chain interactions withdraw concrete amount with properly checks.
    function withdrawAll() external {
        redeem(balanceOf(msg.sender), msg.sender, msg.sender);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      VIEW FUNCTIONS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Total amount of the underlying asset that is “managed” by Vault
    function totalAssets() public view override(ERC4626, IERC4626) returns (uint) {
        return IERC20(asset()).balanceOf(address(this)) + strategy.totalAssets();
    }

    /// @dev Amount of assets under control of strategy.
    function strategyAssets() external view returns (uint) {
        return strategy.totalAssets();
    }

    /// @dev Price of 1 full share
    function sharePrice() external view returns (uint) {
        uint units = 10 ** uint(decimals());
        uint totalSupply_ = totalSupply();
        return totalSupply_ == 0 ? units : units * totalAssets() / totalSupply_;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       INTERNAL LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Calculate available to invest amount and send this amount to strategy
    function _afterDeposit(uint, /*assets*/ uint, /*shares*/ address receiver) internal {
        IStrategyStrict _strategy = strategy;
        IERC20 asset_ = IERC20(asset());

        uint toInvest = _availableToInvest(_strategy, asset_);
        // invest only when buffer is filled
        if (toInvest > 0) {
            asset_.safeTransfer(address(_strategy), toInvest);
            _strategy.investAll();
            emit Invest(address(_strategy), toInvest);

            IGauge(IController(controller).multigauge()).handleBalanceChange(receiver);
        }
    }

    /// @notice Returns amount of assets ready to invest to the strategy
    function _availableToInvest(IStrategyStrict _strategy, IERC20 asset_) internal view returns (uint) {
        uint _buffer = buffer;
        uint assetsInVault = asset_.balanceOf(address(this));
        uint assetsInStrategy = _strategy.totalAssets();
        uint wantInvestTotal = (assetsInVault + assetsInStrategy) * (BUFFER_DENOMINATOR - _buffer) / BUFFER_DENOMINATOR;
        if (assetsInStrategy >= wantInvestTotal) {
            return 0;
        } else {
            uint remainingToInvest = wantInvestTotal - assetsInStrategy;
            return remainingToInvest <= assetsInVault ? remainingToInvest : assetsInVault;
        }
    }

    /// @dev Internal hook for getting necessary assets from strategy.
    function _beforeWithdraw(uint assets, uint shares) internal {
        uint balance = IERC20(asset()).balanceOf(address(this));
        // if not enough balance in the vault withdraw from strategies
        if (balance < assets) {
            _processWithdrawFromStrategy(assets, shares, totalSupply(), buffer, strategy, balance);
        }
    }

    /// @dev Do necessary calculation for withdrawing from strategy and move assets to vault.
    function _processWithdrawFromStrategy(
        uint assetsNeed,
        uint shares,
        uint totalSupply_,
        uint _buffer,
        IStrategyStrict _strategy,
        uint assetsInVault
    ) internal {
        // withdraw everything from the strategy to accurately check the share value
        if (shares == totalSupply_) {
            _strategy.withdrawAllToVault();
        } else {
            uint assetsInStrategy = _strategy.totalAssets();

            // we should always have buffer amount inside the vault
            // assume `assetsNeed` can not be higher than entire balance
            uint expectedBuffer = (assetsInStrategy + assetsInVault - assetsNeed) * _buffer / BUFFER_DENOMINATOR;

            // this code should not be called if `assetsInVault` higher than `assetsNeed`
            uint missing = Math.min(expectedBuffer + assetsNeed - assetsInVault, assetsInStrategy);
            // if zero should be resolved on strategy side
            _strategy.withdrawToVault(missing);
        }
    }
}
