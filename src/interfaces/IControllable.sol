// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface IControllable {
    function isController(address _contract) external view returns (bool);

    function isGovernance(address _contract) external view returns (bool);

    function createdBlock() external view returns (uint);

    function controller() external view returns (address);
}
