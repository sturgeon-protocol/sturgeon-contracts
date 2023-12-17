// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IController.sol";
import "./interfaces/IIFO.sol";
import "./interfaces/IStrategyStrict.sol";

contract IFO is IIFO {
    using SafeERC20 for IERC20;

    // This contract should contain all preminted STGN and allowing to change them to LP rewards until tokens exists on the balance.
    // The exchange will be done by a fixed rate that setup on deploy. Will be not changed later.
    // Rewards will be sent directly to governance.

    address public stgn;
    address public rewardToken;
    address public controller;
    uint public immutable rate;

    constructor(uint rate_) {
        rate = rate_;
    }

    function setup(address controller_, address stgn_, address rewardToken_) external {
        require(stgn_ != address(0) && rewardToken_ != address(0) && controller_ != address(0), "WRONG_INPUT");
        require(stgn == address(0), "ALREADY");
        stgn = stgn_;
        rewardToken = rewardToken_;
        controller = controller_;
        // add event
    }

    function exchange(uint amount) external returns (bool, uint) {
        address vault = IStrategyStrict(msg.sender).vault();
        IController _controller = IController(controller);
        require(_controller.isValidVault(vault), "Not valid vault");
        uint stgnBal = IERC20(stgn).balanceOf(address(this));
        uint stgnOut = amount * rate / 1e18;
        if (stgnOut <= stgnBal) {
            IERC20(rewardToken).safeTransferFrom(msg.sender, _controller.perfFeeTreasury(), amount);
            IERC20(stgn).safeTransfer(msg.sender, stgnOut);
            return (true, stgnOut);
        }

        return (false, 0);
    }
}
