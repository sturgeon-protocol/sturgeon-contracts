// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

interface IControllable {

    function isController(address _contract) external view returns (bool);

    function isGovernance(address _contract) external view returns (bool);

    function createdBlock() external view returns (uint256);

    function controller() external view returns (address);

}
