// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface ILiquidatorControllable {
    function controller() external view returns (address);
}
