// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

interface IIFO {
    event Setup(address controller, address stgn, address rewardToken, uint rate);

    function exchange(uint amount) external returns (bool, uint);
}
