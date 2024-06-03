// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface IController {
    event ProxyUpgradeAnnounced(address proxy, address implementation);
    event ProxyUpgraded(address proxy, address implementation);
    event ProxyAnnounceRemoved(address proxy);
    event RegisterVault(address vault, bool isHarvester);
    event VaultRemoved(address vault, bool isHarvester);
    event OperatorAdded(address operator);
    event OperatorRemoved(address operator);

    struct ProxyAnnounce {
        address proxy;
        address implementation;
        uint timeLockAt;
    }

    // --- DEPENDENCY ADDRESSES

    /// @notice Gnosis safe multi signature wallet with maximum power under the platform.
    function governance() external view returns (address);

    function perfFeeTreasury() external view returns (address);

    function factory() external view returns (address);

    function stgn() external view returns (address);

    /// @notice A dedicated solution for swap tokens via different chains.
    function liquidator() external view returns (address);

    function ifo() external view returns (address);

    //  function investFund() external view returns (address);

    /// @notice Proxy contract for distribute profit to ve holders.
    function veDistributor() external view returns (address);

    /// @notice Gauge for IFO
    function multigauge() external view returns (address);

    // --- VAULTS

    /// @notice Return harvester with given id
    /// @param id Harvester vault ID
    /// @return harvester vault address
    function harvesterVaults(uint id) external view returns (address);

    /// @notice Get all harvesters
    /// @dev Array can be too big for use this function
    /// @return Harvester vault addresses
    function harvesterVaultsList() external view returns (address[] memory);

    /// @notice Total harvesters deployed
    function harvesterVaultsListLength() external view returns (uint);

    /// @notice Return compounder vault with given id
    /// @param id Compounder vault ID
    /// @return compounder vault address
    function compounderVaults(uint id) external view returns (address);

    /// @notice Get all compounders
    /// @dev Array can be too big for use this function
    /// @return compounder vault addresses
    function compounderVaultsList() external view returns (address[] memory);

    /// @notice Total compounders deployed
    function compounderVaultsListLength() external view returns (uint);

    /// @dev Check address to be valid vault
    /// @param vault Harvester or Compounder vault address
    /// @return True if the vault valid
    function isValidVault(address vault) external view returns (bool);

    function registerVault(address vault, bool isHarvester) external;

    function isOperator(address _adr) external view returns (bool);
}
