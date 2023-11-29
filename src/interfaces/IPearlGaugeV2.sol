// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

interface IPearlGaugeV2 {
    function TOKEN() external view returns (address);

    function rewardToken() external view returns (address);

    function balanceOf(address account) external view returns (uint);

    ///@notice see earned rewards for user
    function earned(address account) external view returns (uint);

    ///@notice deposit amount TOKEN
    function deposit(uint amount) external;

    ///@notice withdraw a certain amount of TOKEN
    function withdraw(uint amount) external;

    ///@notice User harvest function
    function getReward() external;
}
