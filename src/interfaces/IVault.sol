// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import "./IStrategyStrict.sol";

interface IVault is IERC4626 {
    // *************************************************************
    //                        EVENTS
    // *************************************************************

    event Invest(address splitter, uint amount);

    /// @dev Connected strategy. Can not be changed.
    function strategy() external view returns (IStrategyStrict);

    function controller() external view returns (address);

    function setStrategy(address strategy) external;
}
