// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

interface IGauge {
    //    function veIds(address stakingToken, address account) external view returns (uint);

    function getReward(address stakingToken, address account, address[] memory tokens) external;

    function getAllRewards(address stakingToken, address account) external;

    function getAllRewardsForTokens(address[] memory stakingTokens, address account) external;

    //    function attachVe(address stakingToken, address account, uint veId) external;

    //    function detachVe(address stakingToken, address account, uint veId) external;

    function handleBalanceChange(address account) external;

    function notifyRewardAmount(address stakingToken, address token, uint amount) external;

    function addStakingToken(address token) external;
}
