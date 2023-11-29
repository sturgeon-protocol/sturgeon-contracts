// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IControllable.sol";
import "../interfaces/IController.sol";
import "../lib/SlotsLib.sol";

/// @title Implement basic functionality for any contract that require strict control
/// @dev Can be used with upgradeable pattern.
///      Require call __Controllable_init() in any case.
/// @author belbix
abstract contract Controllable is Initializable, IControllable {
    using SlotsLib for bytes32;

    /// @notice Version of the contract
    /// @dev Should be incremented when contract changed
    string public constant CONTROLLABLE_VERSION = "1.0.0";

    bytes32 internal constant _CONTROLLER_SLOT = bytes32(uint(keccak256("eip1967.controllable.controller")) - 1);
    bytes32 internal constant _CREATED_BLOCK_SLOT = bytes32(uint(keccak256("eip1967.controllable.created_block")) - 1);

    event ContractInitialized(address controller, uint ts, uint block);

    /// @dev Prevent implementation init
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize contract after setup it as proxy implementation
    ///         Save block.timestamp in the "created" variable
    /// @dev Use it only once after first logic setup
    /// @param controller_ Controller address
    function __Controllable_init(address controller_) internal onlyInitializing {
        require(controller_ != address(0), "Zero controller");
        require(IController(controller_).governance() != address(0), "Zero governance");
        _CONTROLLER_SLOT.set(controller_);
        _CREATED_BLOCK_SLOT.set(block.number);
        emit ContractInitialized(controller_, block.timestamp, block.number);
    }

    /// @dev Return true if given address is controller
    function isController(address _value) public view override returns (bool) {
        return _value == controller();
    }

    /// @notice Return true if given address is setup as governance in Controller
    function isGovernance(address _value) public view override returns (bool) {
        return IController(controller()).governance() == _value;
    }

    // ************* SETTERS/GETTERS *******************

    /// @notice Return controller address saved in the contract slot
    function controller() public view override returns (address) {
        return _CONTROLLER_SLOT.getAddress();
    }

    /// @notice Return creation block number
    /// @return Creation block number
    function createdBlock() external view override returns (uint) {
        return _CREATED_BLOCK_SLOT.getUint();
    }

    /// @dev Gets a slot as bytes32
    function getSlot(uint slot) external view returns (bytes32 result) {
        assembly {
            result := sload(slot)
        }
    }
}
