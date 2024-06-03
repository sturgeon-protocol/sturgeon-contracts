// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface IGaugeV2ALM {
    function box() external view returns (address);

    function rewardToken() external view returns (address);

    function balanceOf(address account) external view returns (uint);

    ///@notice see earned rewards for user
    function earnedReward(address account) external view returns (uint);

    ///@notice deposit amount TOKEN
    function deposit(uint amount) external;

    ///@notice withdraw a certain amount of TOKEN
    function withdraw(uint amount) external;

    ///@notice User harvest function
    function collectReward() external;
}
