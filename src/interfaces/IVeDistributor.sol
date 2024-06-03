// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface IVeDistributor {
    function rewardToken() external view returns (address);

    function checkpoint() external;

    function checkpointTotalSupply() external;

    function claim(uint _tokenId) external returns (uint);
}
