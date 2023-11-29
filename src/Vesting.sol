// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IVesting.sol";

contract Vesting is IVesting {
    using SafeERC20 for IERC20;

    /// @dev Token for vesting
    IERC20 public token;
    /// @dev Will start after the cliff
    uint public vestingPeriod;
    /// @dev Delay before the vesting
    uint public cliffPeriod;
    /// @dev Who will receive the tokens
    address public claimant;

    uint public startTs;
    uint public toDistribute;

    event Started(uint amount, uint time);
    event Claimed(address claimer, uint amount);

    constructor() {}

    function setup(address token_, uint vestingPeriod_, uint cliffPeriod_, address claimant_) external {
        require(token_ != address(0), "WRONG_INPUT");
        require(address(token) == address(0), "ALREADY");
        token = IERC20(token_);
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

    function claim() external {
        address _claimant = claimant;
        require(_claimant == msg.sender, "Not claimant");
        require(startTs != 0, "Not started");

        uint _startTs = startTs;
        require(_startTs < block.timestamp, "Too early");

        uint timeDiff = block.timestamp - _startTs;
        uint toClaim = timeDiff * toDistribute / vestingPeriod;
        uint balance = token.balanceOf(address(this));

        toClaim = balance < toClaim ? balance : toClaim;
        require(toClaim != 0, "Nothing to claim");
        token.safeTransfer(_claimant, toClaim);

        startTs = block.timestamp;
        emit Claimed(_claimant, toClaim);
    }
}
