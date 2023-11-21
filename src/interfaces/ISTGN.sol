// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface ISTGN {
    function vesting() external view returns (address[] memory);
}
