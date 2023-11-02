// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import "./IStrategyStrict.sol";

interface IVault is IERC4626 {
    function strategy() external view returns (IStrategyStrict);

}