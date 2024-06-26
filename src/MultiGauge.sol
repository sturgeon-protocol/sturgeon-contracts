// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IVe.sol";
import "./interfaces/IGauge.sol";
import "./base/StakelessMultiPoolBase.sol";

/// @title Stakeless pool for vaults
/// @author belbix
contract MultiGauge is StakelessMultiPoolBase, IGauge {
    // *************************************************************
    //                        CONSTANTS
    // *************************************************************

    /// @dev Version of this contract. Adjust manually on each code modification.
    string public constant MULTI_GAUGE_VERSION = "1.0.0";

    // *************************************************************
    //                        VARIABLES
    //                Keep names and ordering!
    //                 Add only in the bottom.
    // *************************************************************

    /// @dev The ve token used for gauges
    //    address public ve;
    /// @dev staking token => ve owner => veId
    //    mapping(address => mapping(address => uint)) public override veIds;
    /// @dev Staking token => whitelist status
    mapping(address => bool) public stakingTokens;

    // *************************************************************
    //                        EVENTS
    // *************************************************************

    event AddStakingToken(address token);
    event Deposit(address indexed stakingToken, address indexed account, uint amount);
    event Withdraw( /*, uint veId*/ address indexed stakingToken, address indexed account, uint amount, bool full);
    event VeTokenLocked(address indexed stakingToken, address indexed account, uint tokenId);
    event VeTokenUnlocked(address indexed stakingToken, address indexed account, uint tokenId);

    // *************************************************************
    //                        INIT
    // *************************************************************

    function init(address controller_, address _defaultRewardToken) external initializer {
        __MultiPool_init(controller_, _defaultRewardToken, 7 days);
        //        ve = _ve;
    }

    // *************************************************************
    //                    OPERATOR ACTIONS
    // *************************************************************

    /// @dev Allowed contracts can whitelist token. Removing is forbidden.
    function addStakingToken(address token) external override onlyAllowedContracts {
        stakingTokens[token] = true;
        emit AddStakingToken(token);
    }

    // *************************************************************
    //                        CLAIMS
    // *************************************************************

    function getReward(address stakingToken, address account, address[] memory tokens) external override {
        _getReward(stakingToken, account, tokens);
    }

    function getAllRewards(address stakingToken, address account) external override {
        _getAllRewards(stakingToken, account);
    }

    function _getAllRewards(address stakingToken, address account) internal {
        address[] storage rts = rewardTokens[stakingToken];
        uint length = rts.length;
        address[] memory tokens = new address[](length + 1);
        for (uint i; i < length; ++i) {
            tokens[i] = rts[i];
        }
        tokens[length] = defaultRewardToken;
        _getReward(stakingToken, account, tokens);
    }

    function getAllRewardsForTokens(address[] memory _stakingTokens, address account) external override {
        for (uint i; i < _stakingTokens.length; i++) {
            _getAllRewards(_stakingTokens[i], account);
        }
    }

    function _getReward(address stakingToken, address account, address[] memory tokens) internal {
        //    voter().distribute(stakingToken);
        _getReward(stakingToken, account, tokens, account);
    }

    // *************************************************************
    //                   VIRTUAL DEPOSIT/WITHDRAW
    // *************************************************************

    /*function attachVe(address stakingToken, address account, uint veId) external override {
        require(IERC721(ve).ownerOf(veId) == account && account == msg.sender, "Not ve token owner");
        require(isStakeToken(stakingToken), "Wrong staking token");

        if (veIds[stakingToken][account] == 0) {
            veIds[stakingToken][account] = veId;
            //      voter().attachTokenToGauge(stakingToken, veId, account);
        }
        require(veIds[stakingToken][account] == veId, "Wrong ve");

        _updateDerivedBalance(stakingToken, account);
        _updateRewardForAllTokens(stakingToken, account);
        emit VeTokenLocked(stakingToken, account, veId);
    }*/

    /*function detachVe(address stakingToken, address account, uint veId) external override {
        require(
            (IERC721(ve).ownerOf(veId) == account && msg.sender == account)
                || msg.sender == address(IController(controller()).ifo()),
            "Not ve token owner or voter"
        );
        require(isStakeToken(stakingToken), "Wrong staking token");

        _unlockVeToken(stakingToken, account, veId);
        _updateDerivedBalance(stakingToken, account);
        _updateRewardForAllTokens(stakingToken, account);
    }*/

    /// @dev Must be called from stakingToken when user balance changed.
    function handleBalanceChange(address account) external override {
        address stakingToken = msg.sender;
        require(isStakeToken(stakingToken), "Wrong staking token");

        uint stakedBalance = balanceOf[stakingToken][account];
        uint actualBalance = IERC20(stakingToken).balanceOf(account);
        if (stakedBalance < actualBalance) {
            _deposit(stakingToken, account, actualBalance - stakedBalance);
        } else if (stakedBalance > actualBalance) {
            _withdraw(stakingToken, account, stakedBalance - actualBalance, actualBalance == 0);
        }
    }

    function _deposit(address stakingToken, address account, uint amount) internal {
        _registerBalanceIncreasing(stakingToken, account, amount);
        emit Deposit(stakingToken, account, amount);
    }

    function _withdraw(address stakingToken, address account, uint amount, bool fullWithdraw) internal {
        //        uint veId = 0;
        /*if (fullWithdraw) {
            veId = veIds[stakingToken][account];
        }
        if (veId > 0) {
            _unlockVeToken(stakingToken, account, veId);
        }*/
        _registerBalanceDecreasing(stakingToken, account, amount);
        emit Withdraw(stakingToken, account, amount, fullWithdraw /*, veId*/ );
    }

    /// @dev Balance should be recalculated after the unlock
    /*function _unlockVeToken(address stakingToken, address account, uint veId) internal {
        require(veId == veIds[stakingToken][account], "Wrong ve");
        veIds[stakingToken][account] = 0;
        //    voter().detachTokenFromGauge(stakingToken, veId, account);
        emit VeTokenUnlocked(stakingToken, account, veId);
    }*/

    // *************************************************************
    //                   LOGIC OVERRIDES
    // *************************************************************

    /// @dev Similar to Curve https://resources.curve.fi/reward-gauges/boosting-your-crv-rewards#formula
    function derivedBalance(address stakingToken, address account) public view override returns (uint) {
        return balanceOf[stakingToken][account];
        /*uint _tokenId = veIds[stakingToken][account];
        uint _balance = balanceOf[stakingToken][account];
        uint _derived = _balance * 40 / 100;
        uint _adjusted = 0;
        uint _supply = IERC20(ve).totalSupply();
        if (account == IERC721(ve).ownerOf(_tokenId) && _supply > 0) {
            _adjusted = (totalSupply[stakingToken] * IVe(ve).balanceOfNFT(_tokenId) / _supply) * 60 / 100;
        }
        return Math.min((_derived + _adjusted), _balance);*/
    }

    // *************************************************************
    //                   REWARDS DISTRIBUTION
    // *************************************************************

    function notifyRewardAmount(address stakingToken, address token, uint amount) external override nonReentrant {
        _notifyRewardAmount(stakingToken, token, amount, true);
    }

    // *************************************************************
    //                        VIEWS
    // *************************************************************

    function isStakeToken(address token) public view override returns (bool) {
        return stakingTokens[token];
    }
}
