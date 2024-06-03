// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface IProxyControlled {
    function initProxy(address _logic) external;

    function upgrade(address _newImplementation) external;

    function implementation() external view returns (address);
}
