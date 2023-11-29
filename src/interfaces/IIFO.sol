// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface IIFO {
    function exchange(uint amount) external returns (bool, uint);
}
