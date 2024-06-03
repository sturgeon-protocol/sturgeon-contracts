// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface IStrategyStrict {
    function asset() external view returns (address);

    function vault() external view returns (address);

    function compoundRatio() external view returns (uint);

    function totalAssets() external view returns (uint);

    function lastHardWork() external view returns (uint);

    /// @dev Usually, indicate that claimable rewards have reasonable amount.
    function isReadyToHardWork() external view returns (bool);

    function withdrawAllToVault() external;

    function withdrawToVault(uint amount) external;

    function investAll() external;

    function doHardWork() external; /* returns (uint earned, uint lost)*/
}
