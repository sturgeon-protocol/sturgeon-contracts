// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../src/interfaces/IPearlGaugeV2.sol";

contract MockPearlGaugeV2 {
    address public TOKEN;
    address public rewardToken;
    mapping(address accuont => uint balance) public balanceOf;

    constructor(address TOKEN_, address rewardToken_) {
        TOKEN = TOKEN_;
        rewardToken = rewardToken_;
    }

    ///@notice see earned rewards for user
    function earned(address account) public view returns (uint) {
        // todo changeable
        return balanceOf[account] / 1e10;
    }

    ///@notice deposit amount TOKEN
    function deposit(uint amount) external {
        IERC20(TOKEN).transferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender] += amount;
    }

    ///@notice withdraw a certain amount of TOKEN
    function withdraw(uint amount) external {
        //        require(amount <= balanceOf[msg.sender], "MockPearlGaugeV2: not enough balance");
        IERC20(TOKEN).transfer(msg.sender, amount);
        balanceOf[msg.sender] -= amount;
    }

    ///@notice User harvest function
    function getReward() external {
        IERC20 rt = IERC20(rewardToken);
        uint _earned = earned(msg.sender);
        if (rt.balanceOf(address(this)) >= _earned) {
            IERC20(rewardToken).transfer(msg.sender, earned(msg.sender));
        }
    }
}
