// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.21;

contract IFO {

    // todo implement
    // This contract should contain all preminted STGN and allowing to change them to LP rewards until tokens exists on the balance.
    // The exchange will be done by a fixed rate that setup on deploy. Will be not changed later.
    // Rewards will be sent directly to governance.

    address public stgn;
    uint public immutable rate;

    constructor (uint rate_) {
        rate = rate_;
    }

    function setup(address stgn_) external {
        require (stgn_ != address(0), "WRONG_INPUT");
        require (stgn == address(0), "ALREADY");
        stgn = stgn_;
    }
}