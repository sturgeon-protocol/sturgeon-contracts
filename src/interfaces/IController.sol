// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

interface IController {

  // --- DEPENDENCY ADDRESSES
  function governance() external view returns (address);

//  function voter() external view returns (address);

  /// @notice A dedicated solution for swap tokens via different chains.
  function liquidator() external view returns (address);

  function ifo() external view returns (address);

//  function investFund() external view returns (address);

  /// @notice Proxy contract for distribute profit to ve holders.
  function veDistributor() external view returns (address);

//  function platformVoter() external view returns (address);

  // --- VAULTS

  function vaults(uint id) external view returns (address);

  function vaultsList() external view returns (address[] memory);

  function vaultsListLength() external view returns (uint);

  function isValidVault(address _vault) external view returns (bool);

  // --- restrictions

  function isOperator(address _adr) external view returns (bool);


}
