// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IVe.sol";

contract DepositHelper is ReentrancyGuard {
    using SafeERC20 for IERC20;

    function createLock(IVe ve, address token, uint value, uint lockDuration) external nonReentrant returns (
        uint tokenId,
        uint lockedAmount,
        uint power,
        uint unlockDate
    ) {
        IERC20(token).safeTransferFrom(msg.sender, address(this), value);
        _approveIfNeeds(token, value, address(ve));
        tokenId = ve.createLockFor(token, value, lockDuration, msg.sender);

        lockedAmount = ve.lockedAmounts(tokenId, token);
        power = ve.balanceOfNFT(tokenId);
        unlockDate = ve.lockedEnd(tokenId);

        _sendRemainingToken(token);
    }

    function increaseAmount(IVe ve, address token, uint tokenId, uint value) external nonReentrant returns (
        uint lockedAmount,
        uint power,
        uint unlockDate
    ) {
        IERC20(token).safeTransferFrom(msg.sender, address(this), value);
        _approveIfNeeds(token, value, address(ve));
        ve.increaseAmount(token, tokenId, value);

        lockedAmount = ve.lockedAmounts(tokenId, token);
        power = ve.balanceOfNFT(tokenId);
        unlockDate = ve.lockedEnd(tokenId);

        _sendRemainingToken(token);
    }

    function _approveIfNeeds(address token, uint amount, address spender) internal {
        if (IERC20(token).allowance(address(this), spender) < amount) {
            IERC20(token).forceApprove(spender, type(uint).max);
        }
    }

    function _sendRemainingToken(address token) internal {
        uint balance = IERC20(token).balanceOf(address(this));
        if (balance != 0) {
            IERC20(token).safeTransfer(msg.sender, balance);
        }
    }
}
