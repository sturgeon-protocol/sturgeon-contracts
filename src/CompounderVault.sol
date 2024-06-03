// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IStrategyStrict.sol";
import "./interfaces/IController.sol";
import "./interfaces/IGauge.sol";

/// @title Compounder ERC4626 tokenized vault implementation
/// @author a17
contract CompounderVault is ERC4626, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      INITIALIZATION                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(IERC20 asset_, string memory name_, string memory symbol_) ERC20(name_, symbol_) ERC4626(asset_) {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         USER ACTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IERC4626
    function deposit(uint assets, address receiver) public override nonReentrant returns (uint) {
        uint shares = super.deposit(assets, receiver);
        _afterDeposit(assets, shares, receiver);
        return shares;
    }

    /// @inheritdoc IERC4626
    function mint(uint shares, address receiver) public override nonReentrant returns (uint) {
        uint assets = super.mint(shares, receiver);
        _afterDeposit(assets, shares, receiver);
        return assets;
    }

    /// @inheritdoc IERC4626
    function withdraw(uint assets, address receiver, address owner) public override nonReentrant returns (uint) {
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
    function redeem(uint shares, address receiver, address owner) public override nonReentrant returns (uint) {
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
    function totalAssets() public view override returns (uint) {
        return IERC20(asset()).balanceOf(address(this));
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
    function _afterDeposit(uint, /*assets*/ uint, /*shares*/ address receiver) internal {}

    /// @dev Internal hook for getting necessary assets from strategy.
    function _beforeWithdraw(uint, /*assets*/ uint /*shares*/ ) internal {}
}
