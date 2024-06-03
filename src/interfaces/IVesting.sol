// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

/// @title Vesting contract interface
interface IVesting {

    /// @dev Token for vesting
    function token() external view returns(address);

    /// @dev Period that will start after the cliff
    function vestingPeriod() external view returns(uint);

    /// @dev Delay before the vesting
    function cliffPeriod() external view returns(uint);

    /// @dev Who will receive the tokens
    function claimant() external view returns(address);

    /// @dev Delay before the vesting
    function startTs() external view returns(uint);

    /// @dev Amount to distribute during vesting period
    function toDistribute() external view returns(uint);

    /// @dev Claim tokens
    function claim() external returns(uint amount);
}
