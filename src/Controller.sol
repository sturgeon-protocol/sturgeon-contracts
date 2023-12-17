// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "./interfaces/IProxyControlled.sol";
import "./interfaces/IController.sol";

contract Controller is IController {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         CONSTANTS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    uint public constant TIME_LOCK = 24 hours;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @inheritdoc IController
    address public governance;

    address public perfFeeTreasury;

    address public factory;

    address public stgn;

    /// @dev External solution for sell any tokens with minimal gas usage.
    address public liquidator;

    address public ifo;

    address public ve;

    address public veDistributor;

    address public multigauge;

    mapping(address => address) public proxyAnnounces;

    /// @dev Operators can execute not-critical functions of the platform.
    EnumerableSet.AddressSet internal _operators;

    EnumerableMap.AddressToUintMap internal _proxyTimeLocks;

    /// @dev Set of deployed harvester vaults
    EnumerableSet.AddressSet internal _harvesters;

    /// @dev Set of deployed compounder vaults
    EnumerableSet.AddressSet internal _compounders;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      INITIALIZATION                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(address governance_) {
        require(governance_ != address(0), "WRONG_INPUT");
        governance = governance_;
        _operators.add(governance_);
    }

    function setup(
        address perfFeeTreasury_,
        address factory_,
        address ifo_,
        address ve_,
        address stgn_,
        address multigauge_,
        address liquidator_
    ) external {
        require(
            ifo_ != address(0) && stgn_ != address(0) && multigauge_ != address(0) && ve_ != address(0), "WRONG_INPUT"
        );
        require(ifo == address(0), "ALREADY");
        perfFeeTreasury = perfFeeTreasury_;
        factory = factory_;
        ifo = ifo_;
        ve = ve_;
        stgn = stgn_;
        multigauge = multigauge_;
        liquidator = liquidator_;
        _operators.add(factory_); // todo event
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         MODIFIERS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    modifier onlyOperator() {
        _onlyOperators();
        _;
    }

    modifier onlyGovernance() {
        _onlyGovernance();
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      RESTRICTED ACTIONS                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function announceProxyUpgrade(address[] memory proxies, address[] memory implementations) external onlyGovernance {
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
    function upgradeProxy(address[] memory proxies) external onlyOperator {
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

    function removeProxyAnnounce(address proxy) external onlyOperator {
        _proxyTimeLocks.remove(proxy);
        delete proxyAnnounces[proxy];
        emit ProxyAnnounceRemoved(proxy);
    }

    /// @dev Register vault in the system.
    ///      Operator should do it as part of deployment process.
    function registerVault(address vault, bool isHarvester) external onlyOperator {
        if (isHarvester) {
            require(_harvesters.add(vault), "EXIST");
        } else {
            require(_compounders.add(vault), "EXIST");
        }
        emit RegisterVault(vault, isHarvester);
    }

    /// @dev Remove vault from the system. Only for critical cases.
    function removeVault(address vault, bool isHarvester) external onlyGovernance {
        if (isHarvester) {
            require(_harvesters.remove(vault), "NOT_EXIST");
        } else {
            require(_compounders.remove(vault), "NOT_EXIST");
        }
        emit VaultRemoved(vault, isHarvester);
    }

    /// @dev Register new operator.
    function registerOperator(address value) external onlyGovernance {
        require(_operators.add(value), "EXIST");
        emit OperatorAdded(value);
    }

    /// @dev Remove operator.
    function removeOperator(address value) external onlyGovernance {
        require(_operators.remove(value), "NOT_EXIST");
        emit OperatorRemoved(value);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      VIEW FUNCTIONS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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

    /// @inheritdoc IController
    function harvesterVaultsList() external view override returns (address[] memory) {
        return _harvesters.values();
    }

    /// @inheritdoc IController
    function harvesterVaultsListLength() external view override returns (uint) {
        return _harvesters.length();
    }

    /// @inheritdoc IController
    function harvesterVaults(uint id) external view override returns (address) {
        return _harvesters.at(id);
    }

    /// @inheritdoc IController
    function compounderVaultsList() external view override returns (address[] memory) {
        return _compounders.values();
    }

    /// @inheritdoc IController
    function compounderVaultsListLength() external view override returns (uint) {
        return _compounders.length();
    }

    /// @inheritdoc IController
    function compounderVaults(uint id) external view override returns (address) {
        return _compounders.at(id);
    }

    /// @inheritdoc IController
    function isValidVault(address vault) external view override returns (bool) {
        return _harvesters.contains(vault) || _compounders.contains(vault);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       INTERNAL LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _onlyGovernance() internal view {
        require(msg.sender == governance, "DENIED");
    }

    function _onlyOperators() internal view {
        require(_operators.contains(msg.sender), "DENIED");
    }
}
