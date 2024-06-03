// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IVesting.sol";

/// @title Vesting contract
/// @author Alien Deployer (https://github.com/a17)
contract Vesting is IVesting {
    using SafeERC20 for IERC20;

    /// @inheritdoc IVesting
    address public token;

    /// @inheritdoc IVesting
    uint public vestingPeriod;

    /// @inheritdoc IVesting
    uint public cliffPeriod;

    /// @inheritdoc IVesting
    address public claimant;

    /// @inheritdoc IVesting
    uint public startTs;

    /// @inheritdoc IVesting
    uint public toDistribute;

    event Started(uint amount, uint time);
    event Claimed(address claimer, uint amount);

    constructor() {}

    function setup(address token_, uint vestingPeriod_, uint cliffPeriod_, address claimant_) external {
        require(token_ != address(0), "WRONG_INPUT");
        require(address(token) == address(0), "ALREADY");
        token = token_;
        vestingPeriod = vestingPeriod_;
        cliffPeriod = cliffPeriod_;
        claimant = claimant_;
    }

    function start(uint amount) external {
        require(startTs == 0, "Already started");
        require(IERC20(token).balanceOf(address(this)) == amount, "Incorrect amount");
        startTs = block.timestamp + cliffPeriod;
        toDistribute = amount;
        emit Started(amount, block.timestamp);
    }

    /// @inheritdoc IVesting
    function claim() external returns (uint amount) {
        address _claimant = claimant;
        require(_claimant == msg.sender, "Not claimant");
        require(startTs != 0, "Not started");
        uint _startTs = startTs;
        require(_startTs < block.timestamp, "Too early");
        uint timeDiff = block.timestamp - _startTs;
        amount = timeDiff * toDistribute / vestingPeriod;
        IERC20 _token = IERC20(token);
        uint balance = _token.balanceOf(address(this));
        amount = balance < amount ? balance : amount;
        require(amount != 0, "Nothing to claim");
        _token.safeTransfer(_claimant, amount);
        startTs = block.timestamp;
        emit Claimed(_claimant, amount);
    }
}
