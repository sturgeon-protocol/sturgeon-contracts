// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./interfaces/IProxyControlled.sol";
import "./interfaces/IController.sol";


contract Controller is IController {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    struct ProxyAnnounce {
        address proxy;
        address implementation;
        uint timeLockAt;
    }

    uint public constant TIME_LOCK = 24 hours;

    /// @dev Gnosis safe multi signature wallet with maximum power under the platform.
    address public governance;

    /// @dev External solution for sell any tokens with minimal gas usage.
    address public liquidator;

    address public ifo;

    address public veDistributor;

    /// @dev Operators can execute not-critical functions of the platform.
    EnumerableSet.AddressSet internal _operators;

    mapping(address => address) public proxyAnnounces;
    EnumerableMap.AddressToUintMap internal _proxyTimeLocks;
    /// @dev Set of valid vaults
    EnumerableSet.AddressSet internal _vaults;


    event ProxyUpgradeAnnounced(address proxy, address implementation);
    event ProxyUpgraded(address proxy, address implementation);
    event ProxyAnnounceRemoved(address proxy);
    event RegisterVault(address vault);
    event VaultRemoved(address vault);
    event OperatorAdded(address operator);
    event OperatorRemoved(address operator);

    constructor(address governance_) {
        require(governance_ != address(0), "WRONG_INPUT");
        governance = governance_;
        _operators.add(governance_);
    }

    function setup(address ifo_) external {
        require(ifo_ != address(0), "WRONG_INPUT");
        require (ifo == address(0), "ALREADY");
        ifo = ifo_;
    }

    function _onlyGovernance() internal view {
        require(msg.sender == governance, "DENIED");
    }

    function _onlyOperators() internal view {
        require(_operators.contains(msg.sender), "DENIED");
    }

    /// @dev Return all announced proxy upgrades.
    function proxyAnnouncesList() external view returns (ProxyAnnounce[] memory announces) {
        uint length = _proxyTimeLocks.length();
        announces = new ProxyAnnounce[](length);
        for (uint i; i < length; ++i) {
            (address proxy, uint timeLock) = _proxyTimeLocks.at(i);
            address implementation = proxyAnnounces[proxy];
            announces[i] = ProxyAnnounce(proxy, implementation, timeLock);
        }
    }

    /// @dev Return true if the value exist in the operator set.
    function isOperator(address value) external view override returns (bool) {
        return _operators.contains(value);
    }

    /// @dev Return all operators. Expect the array will have reasonable size.
    function operatorsList() external view returns (address[] memory) {
        return _operators.values();
    }

    /// @dev Return all vaults. Array can be too big for use this function.
    function vaultsList() external view override returns (address[] memory) {
        return _vaults.values();
    }

    /// @dev Vault set size.
    function vaultsListLength() external view override returns (uint) {
        return _vaults.length();
    }

    /// @dev Return vault with given id. Ordering can be changed with time!
    function vaults(uint id) external view override returns (address) {
        return _vaults.at(id);
    }

    /// @dev Return true if the vault valid.
    function isValidVault(address _vault) external view override returns (bool) {
        return _vaults.contains(_vault);
    }

    // *************************************************************
    //          UPGRADE PROXIES WITH TIME-LOCK PROTECTION
    // *************************************************************

    function announceProxyUpgrade(
        address[] memory proxies,
        address[] memory implementations
    ) external {
        _onlyGovernance();
        require(proxies.length == implementations.length, "WRONG_INPUT");

        for (uint i; i < proxies.length; i++) {
            address proxy = proxies[i];
            address implementation = implementations[i];

            require(implementation != address(0), "ZERO_IMPL");
            require(_proxyTimeLocks.set(proxy, block.timestamp + TIME_LOCK), "ANNOUNCED");
            proxyAnnounces[proxy] = implementation;

            emit ProxyUpgradeAnnounced(proxy, implementation);
        }
    }

    /// @dev Upgrade proxy. Less strict for reduce governance actions.
    function upgradeProxy(address[] memory proxies) external {
        _onlyOperators();

        for (uint i; i < proxies.length; i++) {
            address proxy = proxies[i];
            uint timeLock = _proxyTimeLocks.get(proxy);
            // Map get will revert on not exist key, no need to check to zero
            address implementation = proxyAnnounces[proxy];

            require(timeLock < block.timestamp, "LOCKED");

            IProxyControlled(proxy).upgrade(implementation);

            _proxyTimeLocks.remove(proxy);
            delete proxyAnnounces[proxy];

            emit ProxyUpgraded(proxy, implementation);
        }
    }

    function removeProxyAnnounce(address proxy) external {
        _onlyOperators();

        _proxyTimeLocks.remove(proxy);
        delete proxyAnnounces[proxy];

        emit ProxyAnnounceRemoved(proxy);
    }

    // *************************************************************
    //                     REGISTER ACTIONS
    // *************************************************************

    /// @dev Register vault in the system.
    ///      Operator should do it as part of deployment process.
    function registerVault(address vault) external {
        _onlyOperators();

        require(_vaults.add(vault), "EXIST");
        emit RegisterVault(vault);
    }

    /// @dev Remove vault from the system. Only for critical cases.
    function removeVault(address vault) external {
        _onlyGovernance();

        require(_vaults.remove(vault), "NOT_EXIST");
        emit VaultRemoved(vault);
    }

    /// @dev Register new operator.
    function registerOperator(address value) external {
        _onlyGovernance();

        require(_operators.add(value), "EXIST");
        emit OperatorAdded(value);
    }

    /// @dev Remove operator.
    function removeOperator(address value) external {
        _onlyGovernance();

        require(_operators.remove(value), "NOT_EXIST");
        emit OperatorRemoved(value);
    }
}
