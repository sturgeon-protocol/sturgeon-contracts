// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "./interfaces/IVe.sol";
import "./interfaces/IController.sol";
import "./base/Controllable.sol";
import "./lib/VeSTGNLib.sol";

/// @title Voting escrow NFT for multiple underlying tokens.
///        Based on Curve/Solidly contract.
/// @author belbix
contract VeSTGN is Controllable, ReentrancyGuard, IVe {
    using SafeERC20 for IERC20;
    using Math for uint;

    // Only for internal usage
    struct DepositInfo {
        address stakingToken;
        uint tokenId;
        uint value;
        uint unlockTime;
        uint lockedAmount;
        uint lockedDerivedAmount;
        uint lockedEnd;
        DepositType depositType;
    }

    // Only for internal usage
    struct CheckpointInfo {
        uint tokenId;
        uint oldDerivedAmount;
        uint newDerivedAmount;
        uint oldEnd;
        uint newEnd;
        bool isAlwaysMaxLock;
    }

    enum TimeLockType {
        UNKNOWN,
        ADD_TOKEN,
        WHITELIST_TRANSFER
    }

    // *************************************************************
    //                        CONSTANTS
    // *************************************************************

    /// @dev Version of this contract. Adjust manually on each code modification.
    string public constant VE_VERSION = "1.3.0";
    uint internal constant WEEK = 1 weeks;
    uint internal constant MAX_TIME = 16 weeks;
    uint public constant GOV_ACTION_TIME_LOCK = 18 hours;

    string public constant override name = "veSTGN";
    string public constant override symbol = "veSTGN";

    /// @dev ERC165 interface ID of ERC165
    bytes4 internal constant _ERC165_INTERFACE_ID = 0x01ffc9a7;
    /// @dev ERC165 interface ID of ERC721
    bytes4 internal constant _ERC721_INTERFACE_ID = 0x80ac58cd;
    /// @dev ERC165 interface ID of ERC721Metadata
    bytes4 internal constant _ERC721_METADATA_INTERFACE_ID = 0x5b5e139f;

    // *************************************************************
    //                        VARIABLES
    //                Keep names and ordering!
    //                 Add only in the bottom.
    // *************************************************************

    /// @dev Underlying tokens info
    address[] public override tokens;
    /// @dev token => weight
    mapping(address => uint) public tokenWeights;
    /// @dev token => is allowed for deposits
    mapping(address => bool) public isValidToken;
    /// @dev Current count of token
    uint public tokenId;
    /// @dev veId => stakingToken => Locked amount
    mapping(uint => mapping(address => uint)) public override lockedAmounts;
    /// @dev veId => Amount based on weights aka power
    mapping(uint => uint) public override lockedDerivedAmount;
    /// @dev veId => Lock end timestamp
    mapping(uint => uint) internal _lockedEndReal;

    // --- CHECKPOINTS LOGIC

    /// @dev Epoch counter. Update each week.
    uint public override epoch;
    /// @dev epoch -> unsigned point
    mapping(uint => Point) internal _pointHistory;
    /// @dev user -> Point[userEpoch]
    mapping(uint => Point[1000000000]) internal _userPointHistory;
    /// @dev veId -> Personal epoch counter
    mapping(uint => uint) public override userPointEpoch;
    /// @dev time -> signed slope change
    mapping(uint => int128) public slopeChanges;

    // --- STATISTICS

    /// @dev veId -> Block number when last time NFT owner changed
    mapping(uint => uint) public ownershipChange;
    /// @dev Mapping from NFT ID to the address that owns it.
    mapping(uint => address) internal _idToOwner;
    /// @dev Mapping from NFT ID to approved address.
    mapping(uint => address) internal _idToApprovals;
    /// @dev Mapping from owner address to count of his tokens.
    mapping(address => uint) internal _ownerToNFTokenCount;
    /// @dev Mapping from owner address to mapping of index to tokenIds
    mapping(address => mapping(uint => uint)) internal _ownerToNFTokenIdList;
    /// @dev Mapping from NFT ID to index of owner
    mapping(uint => uint) public tokenToOwnerIndex;
    /// @dev Mapping from owner address to mapping of operator addresses.
    mapping(address => mapping(address => bool)) public ownerToOperators;

    /// @dev Mapping of interface id to bool about whether or not it's supported
    mapping(bytes4 => bool) internal _supportedInterfaces;

    // --- PERMISSIONS

    /// @dev Whitelisted contracts will be able to transfer NFTs
    mapping(address => bool) public isWhitelistedTransfer;
    /// @dev Time-locks for governance actions. Zero means not announced and should not processed.
    mapping(TimeLockType => uint) public govActionTimeLock;
    /// @dev underlying token => true if we can stake token to some place, false if paused
    mapping(address => bool) internal tokenFarmingStatus;

    // --- OTHER
    mapping(uint => bool) public isAlwaysMaxLock;
    uint public additionalTotalSupply;

    // *************************************************************
    //                        EVENTS
    // *************************************************************

    event Deposit(
        address indexed stakingToken,
        address indexed provider,
        uint tokenId,
        uint value,
        uint indexed locktime,
        DepositType depositType,
        uint ts
    );
    event Withdraw(address indexed stakingToken, address indexed provider, uint tokenId, uint value, uint ts);
    event Merged(address indexed stakingToken, address indexed provider, uint from, uint to);
    event Split(uint parentTokenId, uint newTokenId, uint percent);
    event TransferWhitelisted(address value);
    event StakingTokenAdded(address value, uint weight);
    event GovActionAnnounced(uint _type, uint timeToExecute);
    event AlwaysMaxLock(uint tokenId, bool status);

    // *************************************************************
    //                        INIT
    // *************************************************************

    /// @dev Proxy initialization. Call it after contract deploy.
    /// @param token_ Underlying ERC20 token
    /// @param controller_ Central contract of the protocol
    function init(address token_, uint weight, address controller_) external initializer {
        __Controllable_init(controller_);

        // the first token should have 18 decimals
        require(IERC20Metadata(token_).decimals() == uint8(18));
        _addToken(token_, weight);

        _pointHistory[0].blk = block.number;
        _pointHistory[0].ts = block.timestamp;

        _supportedInterfaces[_ERC165_INTERFACE_ID] = true;
        _supportedInterfaces[_ERC721_INTERFACE_ID] = true;
        _supportedInterfaces[_ERC721_METADATA_INTERFACE_ID] = true;

        // mint-ish
        emit Transfer(address(0), address(this), 0);
        // burn-ish
        emit Transfer(address(this), address(0), 0);
    }

    // *************************************************************
    //                        GOVERNANCE ACTIONS
    // *************************************************************

    function announceAction(TimeLockType _type) external {
        require(isGovernance(msg.sender), "FORBIDDEN");
        require(govActionTimeLock[_type] == 0 && _type != TimeLockType.UNKNOWN, "WRONG_INPUT");

        govActionTimeLock[_type] = block.timestamp + GOV_ACTION_TIME_LOCK;
        emit GovActionAnnounced(uint(_type), block.timestamp + GOV_ACTION_TIME_LOCK);
    }

    /// @dev Whitelist address for transfers. Removing from whitelist should be forbidden.
    function whitelistTransferFor(address value) external {
        require(isGovernance(msg.sender), "FORBIDDEN");
        require(value != address(0), "WRONG_INPUT");
        uint timeLock = govActionTimeLock[TimeLockType.WHITELIST_TRANSFER];
        require(timeLock != 0 && timeLock < block.timestamp, "TIME_LOCK");

        isWhitelistedTransfer[value] = true;
        govActionTimeLock[TimeLockType.WHITELIST_TRANSFER] = 0;

        emit TransferWhitelisted(value);
    }

    function addToken(address token, uint weight) external {
        require(isGovernance(msg.sender), "FORBIDDEN");
        uint timeLock = govActionTimeLock[TimeLockType.ADD_TOKEN];
        require(timeLock != 0 && timeLock < block.timestamp, "TIME_LOCK");

        _addToken(token, weight);
        govActionTimeLock[TimeLockType.ADD_TOKEN] = 0;
    }

    function _addToken(address token, uint weight) internal {
        require(token != address(0) && weight != 0, "WRONG_INPUT");

        uint length = tokens.length;
        for (uint i; i < length; ++i) {
            require(token != tokens[i], "WRONG_INPUT");
        }

        tokens.push(token);
        tokenWeights[token] = weight;
        isValidToken[token] = true;

        emit StakingTokenAdded(token, weight);
    }

    function changeTokenFarmingAllowanceStatus(address _token, bool status) external {
        require(isGovernance(msg.sender), "FORBIDDEN");
        require(tokenFarmingStatus[_token] != status);
        tokenFarmingStatus[_token] = status;
    }

    // *************************************************************
    //                        VIEWS
    // *************************************************************

    function lockedEnd(uint _tokenId) public view override returns (uint) {
        if (isAlwaysMaxLock[_tokenId]) {
            return (block.timestamp + MAX_TIME) / WEEK * WEEK;
        } else {
            return _lockedEndReal[_tokenId];
        }
    }

    /// @dev Return length of staking tokens.
    function tokensLength() external view returns (uint) {
        return tokens.length;
    }

    /// @dev Current block timestamp
    function blockTimestamp() external view returns (uint) {
        return block.timestamp;
    }

    /// @dev Interface identification is specified in ERC-165.
    /// @param _interfaceID Id of the interface
    function supportsInterface(bytes4 _interfaceID) public view returns (bool) {
        return _supportedInterfaces[_interfaceID];
    }

    /// @notice Get the most recently recorded rate of voting power decrease for `_tokenId`
    /// @param _tokenId token of the NFT
    /// @return Value of the slope
    function getLastUserSlope(uint _tokenId) external view returns (int128) {
        uint uEpoch = userPointEpoch[_tokenId];
        return _userPointHistory[_tokenId][uEpoch].slope;
    }

    /// @notice Get the timestamp for checkpoint `_idx` for `_tokenId`
    /// @param _tokenId token of the NFT
    /// @param _idx User epoch number
    /// @return Epoch time of the checkpoint
    function userPointHistoryTs(uint _tokenId, uint _idx) external view returns (uint) {
        return _userPointHistory[_tokenId][_idx].ts;
    }

    /// @dev Returns the number of NFTs owned by `_owner`.
    ///      Throws if `_owner` is the zero address. NFTs assigned to the zero address are considered invalid.
    /// @param _owner Address for whom to query the balance.
    function _balance(address _owner) internal view returns (uint) {
        return _ownerToNFTokenCount[_owner];
    }

    /// @dev Returns the number of NFTs owned by `_owner`.
    ///      Throws if `_owner` is the zero address. NFTs assigned to the zero address are considered invalid.
    /// @param _owner Address for whom to query the balance.
    function balanceOf(address _owner) external view override returns (uint) {
        return _balance(_owner);
    }

    /// @dev Returns the address of the owner of the NFT.
    /// @param _tokenId The identifier for an NFT.
    function ownerOf(uint _tokenId) public view override returns (address) {
        return _idToOwner[_tokenId];
    }

    /// @dev Get the approved address for a single NFT.
    /// @param _tokenId ID of the NFT to query the approval of.
    function getApproved(uint _tokenId) external view override returns (address) {
        return _idToApprovals[_tokenId];
    }

    /// @dev Checks if `_operator` is an approved operator for `_owner`.
    /// @param _owner The address that owns the NFTs.
    /// @param _operator The address that acts on behalf of the owner.
    function isApprovedForAll(address _owner, address _operator) external view override returns (bool) {
        return (ownerToOperators[_owner])[_operator];
    }

    /// @dev  Get token by index
    function tokenOfOwnerByIndex(address _owner, uint _tokenIndex) external view returns (uint) {
        return _ownerToNFTokenIdList[_owner][_tokenIndex];
    }

    /// @dev Returns whether the given spender can transfer a given token ID
    /// @param _spender address of the spender to query
    /// @param _tokenId uint ID of the token to be transferred
    /// @return bool whether the msg.sender is approved for the given token ID,
    ///              is an operator of the owner, or is the owner of the token
    function isApprovedOrOwner(address _spender, uint _tokenId) public view override returns (bool) {
        address owner = _idToOwner[_tokenId];
        bool spenderIsOwner = owner == _spender;
        bool spenderIsApproved = _spender == _idToApprovals[_tokenId];
        bool spenderIsApprovedForAll = (ownerToOperators[owner])[_spender];
        return spenderIsOwner || spenderIsApproved || spenderIsApprovedForAll;
    }

    function balanceOfNFT(uint _tokenId) public view override returns (uint) {
        // flash NFT protection
        if (ownershipChange[_tokenId] == block.number) {
            return 0;
        }
        return _balanceOfNFT(_tokenId, block.timestamp);
    }

    function balanceOfNFTAt(uint _tokenId, uint _t) external view returns (uint) {
        return _balanceOfNFT(_tokenId, _t);
    }

    function totalSupply() external view returns (uint) {
        return totalSupplyAtT(block.timestamp);
    }

    function balanceOfAtNFT(uint _tokenId, uint _block) external view returns (uint) {
        return _balanceOfAtNFT(_tokenId, _block);
    }

    function userPointHistory(uint _tokenId, uint _loc) external view override returns (Point memory) {
        return _userPointHistory[_tokenId][_loc];
    }

    function pointHistory(uint _loc) external view override returns (Point memory) {
        return _pointHistory[_loc];
    }

    // *************************************************************
    //                        NFT LOGIC
    // *************************************************************

    /// @dev Add a NFT to an index mapping to a given address
    /// @param _to address of the receiver
    /// @param _tokenId uint ID Of the token to be added
    function _addTokenToOwnerList(address _to, uint _tokenId) internal {
        uint currentCount = _balance(_to);

        _ownerToNFTokenIdList[_to][currentCount] = _tokenId;
        tokenToOwnerIndex[_tokenId] = currentCount;
    }

    /// @dev Remove a NFT from an index mapping to a given address
    /// @param _from address of the sender
    /// @param _tokenId uint ID Of the token to be removed
    function _removeTokenFromOwnerList(address _from, uint _tokenId) internal {
        // Delete
        uint currentCount = _balance(_from) - 1;
        uint currentIndex = tokenToOwnerIndex[_tokenId];

        if (currentCount == currentIndex) {
            // update ownerToNFTokenIdList
            _ownerToNFTokenIdList[_from][currentCount] = 0;
            // update tokenToOwnerIndex
            tokenToOwnerIndex[_tokenId] = 0;
        } else {
            uint lastTokenId = _ownerToNFTokenIdList[_from][currentCount];

            // Add
            // update ownerToNFTokenIdList
            _ownerToNFTokenIdList[_from][currentIndex] = lastTokenId;
            // update tokenToOwnerIndex
            tokenToOwnerIndex[lastTokenId] = currentIndex;

            // Delete
            // update ownerToNFTokenIdList
            _ownerToNFTokenIdList[_from][currentCount] = 0;
            // update tokenToOwnerIndex
            tokenToOwnerIndex[_tokenId] = 0;
        }
    }

    /// @dev Add a NFT to a given address
    function _addTokenTo(address _to, uint _tokenId) internal {
        // assume always call on new tokenId or after _removeTokenFrom() call
        // Change the owner
        _idToOwner[_tokenId] = _to;
        // Update owner token index tracking
        _addTokenToOwnerList(_to, _tokenId);
        // Change count tracking
        _ownerToNFTokenCount[_to] += 1;
    }

    /// @dev Remove a NFT from a given address
    ///      Throws if `_from` is not the current owner.
    function _removeTokenFrom(address _from, uint _tokenId) internal {
        require(_idToOwner[_tokenId] == _from, "NOT_OWNER");
        // Change the owner
        _idToOwner[_tokenId] = address(0);
        // Update owner token index tracking
        _removeTokenFromOwnerList(_from, _tokenId);
        // Change count tracking
        _ownerToNFTokenCount[_from] -= 1;
    }

    /// @dev Execute transfer of a NFT.
    ///      Throws unless `msg.sender` is the current owner, an authorized operator, or the approved
    ///      address for this NFT. (NOTE: `msg.sender` not allowed in internal function so pass `_sender`.)
    ///      Throws if `_to` is the zero address.
    ///      Throws if `_from` is not the current owner.
    ///      Throws if `_tokenId` is not a valid NFT.
    function _transferFrom(address _from, address _to, uint _tokenId, address _sender) internal {
        require(isApprovedOrOwner(_sender, _tokenId), "NOT_OWNER");
        require(_to != address(0), "WRONG_INPUT");
        // from address will be checked in _removeTokenFrom()

        if (_idToApprovals[_tokenId] != address(0)) {
            // Reset approvals
            _idToApprovals[_tokenId] = address(0);
        }
        _removeTokenFrom(_from, _tokenId);
        _addTokenTo(_to, _tokenId);
        // Set the block of ownership transfer (for Flash NFT protection)
        ownershipChange[_tokenId] = block.number;
        // Log the transfer
        emit Transfer(_from, _to, _tokenId);
    }

    /// @dev Transfers forbidden for veSTGN
    function transferFrom(address, address, uint) external pure override {
        revert("FORBIDDEN");
        //    _transferFrom(_from, _to, _tokenId, msg.sender);
    }

    function _isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.
        uint size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /// @dev Transfers the ownership of an NFT from one address to another address.
    ///      Throws unless `msg.sender` is the current owner, an authorized operator, or the
    ///      approved address for this NFT.
    ///      Throws if `_from` is not the current owner.
    ///      Throws if `_to` is the zero address.
    ///      Throws if `_tokenId` is not a valid NFT.
    ///      If `_to` is a smart contract, it calls `onERC721Received` on `_to` and throws if
    ///      the return value is not `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`.
    /// @param _from The current owner of the NFT.
    /// @param _to The new owner.
    /// @param _tokenId The NFT to transfer.
    /// @param _data Additional data with no specified format, sent in call to `_to`.
    function safeTransferFrom(address _from, address _to, uint _tokenId, bytes memory _data) public override {
        require(isWhitelistedTransfer[_to] || isWhitelistedTransfer[_from], "FORBIDDEN");

        _transferFrom(_from, _to, _tokenId, msg.sender);
        require(
            _checkOnERC721Received(_from, _to, _tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /// @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
    /// The call is not executed if the target address is not a contract.
    ///
    /// @param _from address representing the previous owner of the given token ID
    /// @param _to target address that will receive the tokens
    /// @param _tokenId uint256 ID of the token to be transferred
    /// @param _data bytes optional data to send along with the call
    /// @return bool whether the call correctly returned the expected magic value
    ///
    function _checkOnERC721Received(
        address _from,
        address _to,
        uint _tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (_isContract(_to)) {
            try IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /// @dev Transfers the ownership of an NFT from one address to another address.
    ///      Throws unless `msg.sender` is the current owner, an authorized operator, or the
    ///      approved address for this NFT.
    ///      Throws if `_from` is not the current owner.
    ///      Throws if `_to` is the zero address.
    ///      Throws if `_tokenId` is not a valid NFT.
    ///      If `_to` is a smart contract, it calls `onERC721Received` on `_to` and throws if
    ///      the return value is not `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`.
    /// @param _from The current owner of the NFT.
    /// @param _to The new owner.
    /// @param _tokenId The NFT to transfer.
    function safeTransferFrom(address _from, address _to, uint _tokenId) external override {
        safeTransferFrom(_from, _to, _tokenId, "");
    }

    /// @dev Set or reaffirm the approved address for an NFT. The zero address indicates there is no approved address.
    ///      Throws unless `msg.sender` is the current NFT owner, or an authorized operator of the current owner.
    ///      Throws if `_tokenId` is not a valid NFT. (NOTE: This is not written the EIP)
    ///      Throws if `_approved` is the current owner. (NOTE: This is not written the EIP)
    /// @param _approved Address to be approved for the given NFT ID.
    /// @param _tokenId ID of the token to be approved.
    function approve(address _approved, uint _tokenId) public override {
        address owner = _idToOwner[_tokenId];
        // Throws if `_tokenId` is not a valid NFT
        require(owner != address(0), "WRONG_INPUT");
        // Throws if `_approved` is the current owner
        require(_approved != owner, "IDENTICAL_ADDRESS");
        // Check requirements
        bool senderIsOwner = (owner == msg.sender);
        bool senderIsApprovedForAll = (ownerToOperators[owner])[msg.sender];
        require(senderIsOwner || senderIsApprovedForAll, "NOT_OWNER");
        // Set the approval
        _idToApprovals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    /// @dev Enables or disables approval for a third party ("operator") to manage all of
    ///      `msg.sender`'s assets. It also emits the ApprovalForAll event.
    ///      Throws if `_operator` is the `msg.sender`. (NOTE: This is not written the EIP)
    /// @notice This works even if sender doesn't own any tokens at the time.
    /// @param _operator Address to add to the set of authorized operators.
    /// @param _approved True if the operators is approved, false to revoke approval.
    function setApprovalForAll(address _operator, bool _approved) external override {
        // Throws if `_operator` is the `msg.sender`
        require(_operator != msg.sender, "IDENTICAL_ADDRESS");
        ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /// @dev Function to mint tokens
    ///      Throws if `_to` is zero address.
    ///      Throws if `_tokenId` is owned by someone.
    /// @param _to The address that will receive the minted tokens.
    /// @param _tokenId The token id to mint.
    /// @return A boolean that indicates if the operation was successful.
    function _mint(address _to, uint _tokenId) internal returns (bool) {
        // Throws if `_to` is zero address
        require(_to != address(0), "WRONG_INPUT");
        _addTokenTo(_to, _tokenId);
        require(
            _checkOnERC721Received(address(0), _to, _tokenId, ""), "ERC721: transfer to non ERC721Receiver implementer"
        );
        emit Transfer(address(0), _to, _tokenId);
        return true;
    }

    // *************************************************************
    //                  DEPOSIT/WITHDRAW LOGIC
    // *************************************************************

    /// @notice Deposit and lock tokens for a user
    function _depositFor(DepositInfo memory info) internal {
        uint newLockedDerivedAmount = info.lockedDerivedAmount;
        if (info.value != 0) {
            // calculate new amounts
            uint newAmount = info.lockedAmount + info.value;
            newLockedDerivedAmount = VeSTGNLib.calculateDerivedAmount(
                info.lockedAmount,
                info.lockedDerivedAmount,
                newAmount,
                tokenWeights[info.stakingToken],
                IERC20Metadata(info.stakingToken).decimals()
            );
            // update chain info
            lockedAmounts[info.tokenId][info.stakingToken] = newAmount;
            _updateLockedDerivedAmount(info.tokenId, newLockedDerivedAmount);
        }

        // Adding to existing lock, or if a lock is expired - creating a new one
        uint newLockedEnd = info.lockedEnd;
        if (info.unlockTime != 0) {
            _lockedEndReal[info.tokenId] = info.unlockTime;
            newLockedEnd = info.unlockTime;
        }

        // update checkpoint
        _checkpoint(
            CheckpointInfo(
                info.tokenId,
                info.lockedDerivedAmount,
                newLockedDerivedAmount,
                info.lockedEnd,
                newLockedEnd,
                isAlwaysMaxLock[info.tokenId]
            )
        );

        // move tokens to this contract, if necessary
        emit Deposit(
            info.stakingToken, msg.sender, info.tokenId, info.value, newLockedEnd, info.depositType, block.timestamp
        );
    }

    function _lockInfo(
        address stakingToken,
        uint veId
    ) internal view returns (uint _lockedAmount, uint _lockedDerivedAmount, uint _lockedEnd) {
        _lockedAmount = lockedAmounts[veId][stakingToken];
        _lockedDerivedAmount = lockedDerivedAmount[veId];
        _lockedEnd = lockedEnd(veId);
    }

    function _incrementTokenIdAndGet() internal returns (uint) {
        uint current = tokenId;
        tokenId = current + 1;
        return current + 1;
    }

    /// @dev Setup always max lock. If true given tokenId will be always counted with max possible lock and can not be withdrawn.
    ///      When deactivated setup a new counter with max lock duration and use all common logic.
    /*function setAlwaysMaxLock(uint _tokenId, bool status) external {
    require(isApprovedOrOwner(msg.sender, _tokenId), "NOT_OWNER");
    require(status != isAlwaysMaxLock[_tokenId], "WRONG_INPUT");

    _setAlwaysMaxLock(_tokenId, status);
    }*/

    function _setAlwaysMaxLock(uint _tokenId, bool status) internal {
        // need to setup first, it will be checked later
        isAlwaysMaxLock[_tokenId] = status;

        uint _derivedAmount = lockedDerivedAmount[_tokenId];
        uint maxLockDuration = (block.timestamp + MAX_TIME) / WEEK * WEEK;

        // the idea is exclude nft from checkpoint calculations when max lock activated and count the balance as is
        if (status) {
            // need to increase additional total supply for properly calculation
            additionalTotalSupply += _derivedAmount;

            // set checkpoints to zero
            _checkpoint(
                CheckpointInfo(
                    _tokenId,
                    _derivedAmount,
                    0,
                    maxLockDuration,
                    maxLockDuration,
                    false // need to use false for this fake update
                )
            );
        } else {
            // remove from additional supply
            require(additionalTotalSupply >= _derivedAmount, "WRONG_SUPPLY");
            additionalTotalSupply -= _derivedAmount;
            // if we disable need to set real lock end to max value
            _lockedEndReal[_tokenId] = maxLockDuration;
            // and activate real checkpoints + total supply
            _checkpoint(
                CheckpointInfo(
                    _tokenId,
                    0, // it was setup to zero when we set always max lock
                    _derivedAmount,
                    maxLockDuration,
                    maxLockDuration,
                    false
                )
            );
        }

        emit AlwaysMaxLock(_tokenId, status);
    }

    function _updateLockedDerivedAmount(uint _tokenId, uint amount) internal {
        uint cur = lockedDerivedAmount[_tokenId];
        if (cur == amount) {
            // if did not change do nothing
            return;
        }

        if (isAlwaysMaxLock[_tokenId]) {
            if (cur > amount) {
                additionalTotalSupply -= (cur - amount);
            } else if (cur < amount) {
                additionalTotalSupply += amount - cur;
            }
        }

        lockedDerivedAmount[_tokenId] = amount;
    }

    /// @notice Deposit `_value` tokens for `_to` and lock for `_lock_duration`
    /// @param _token Token for deposit. Should be whitelisted in this contract.
    /// @param _value Amount to deposit
    /// @param _lockDuration Number of seconds to lock tokens for (rounded down to nearest week)
    /// @param _to Address to deposit
    function _createLock(address _token, uint _value, uint _lockDuration, address _to) internal returns (uint) {
        require(_value > 0, "WRONG_INPUT");
        // Lock time is rounded down to weeks
        uint unlockTime = (block.timestamp + _lockDuration) / WEEK * WEEK;
        require(unlockTime > block.timestamp, "LOW_LOCK_PERIOD");
        require(unlockTime <= block.timestamp + MAX_TIME, "HIGH_LOCK_PERIOD");
        require(isValidToken[_token], "INVALID_TOKEN");

        uint _tokenId = _incrementTokenIdAndGet();
        _mint(_to, _tokenId);

        _depositFor(
            DepositInfo({
                stakingToken: _token,
                tokenId: _tokenId,
                value: _value,
                unlockTime: unlockTime,
                lockedAmount: 0,
                lockedDerivedAmount: 0,
                lockedEnd: 0,
                depositType: DepositType.CREATE_LOCK_TYPE
            })
        );
        return _tokenId;
    }

    /// @notice Deposit `_value` tokens for `_to` and lock for `_lock_duration`
    /// @param _token Token for deposit. Should be whitelisted in this contract.
    /// @param _value Amount to deposit
    /// @param _lockDuration Number of seconds to lock tokens for (rounded down to nearest week)
    /// @param _to Address to deposit
    function createLockFor(
        address _token,
        uint _value,
        uint _lockDuration,
        address _to
    ) external override nonReentrant returns (uint) {
        return _createLock(_token, _value, _lockDuration, _to);
    }

    /// @notice Deposit `_value` tokens for `msg.sender` and lock for `_lock_duration`
    /// @param _value Amount to deposit
    /// @param _lockDuration Number of seconds to lock tokens for (rounded down to nearest week)
    function createLock(address _token, uint _value, uint _lockDuration) external nonReentrant returns (uint) {
        return _createLock(_token, _value, _lockDuration, msg.sender);
    }

    /// @notice Deposit `_value` additional tokens for `_tokenId` without modifying the unlock time
    /// @dev Anyone (even a smart contract) can deposit for someone else, but
    ///      cannot extend their locktime and deposit for a brand new user
    /// @param _token Token for deposit. Should be whitelisted in this contract.
    /// @param _tokenId ve token ID
    /// @param _value Amount of tokens to deposit and add to the lock
    function increaseAmount(address _token, uint _tokenId, uint _value) external override nonReentrant {
        require(_value > 0, "WRONG_INPUT");
        (uint _lockedAmount, uint _lockedDerivedAmount, uint _lockedEnd) = _lockInfo(_token, _tokenId);

        require(_lockedDerivedAmount > 0, "NFT_WITHOUT_POWER");
        require(_lockedEnd > block.timestamp, "EXPIRED");
        require(isValidToken[_token], "INVALID_TOKEN");

        _depositFor(
            DepositInfo({
                stakingToken: _token,
                tokenId: _tokenId,
                value: _value,
                unlockTime: 0,
                lockedAmount: _lockedAmount,
                lockedDerivedAmount: _lockedDerivedAmount,
                lockedEnd: _lockedEnd,
                depositType: DepositType.INCREASE_LOCK_AMOUNT
            })
        );
    }

    /// @notice Extend the unlock time for `_tokenId`
    /// @param _tokenId ve token ID
    /// @param _lockDuration New number of seconds until tokens unlock
    function increaseUnlockTime(
        uint _tokenId,
        uint _lockDuration
    ) external nonReentrant returns (uint power, uint unlockDate) {
        uint _lockedDerivedAmount = lockedDerivedAmount[_tokenId];
        uint _lockedEnd = _lockedEndReal[_tokenId];
        // Lock time is rounded down to weeks
        uint unlockTime = (block.timestamp + _lockDuration) / WEEK * WEEK;
        require(!isAlwaysMaxLock[_tokenId], "ALWAYS_MAX_LOCK");
        require(_lockedDerivedAmount > 0, "NFT_WITHOUT_POWER");
        require(_lockedEnd > block.timestamp, "EXPIRED");
        require(unlockTime > _lockedEnd, "LOW_UNLOCK_TIME");
        require(unlockTime <= block.timestamp + MAX_TIME, "HIGH_LOCK_PERIOD");
        require(isApprovedOrOwner(msg.sender, _tokenId), "NOT_OWNER");

        _depositFor(
            DepositInfo({
                stakingToken: address(0),
                tokenId: _tokenId,
                value: 0,
                unlockTime: unlockTime,
                lockedAmount: 0,
                lockedDerivedAmount: _lockedDerivedAmount,
                lockedEnd: _lockedEnd,
                depositType: DepositType.INCREASE_UNLOCK_TIME
            })
        );

        power = balanceOfNFT(_tokenId);
        unlockDate = _lockedEndReal[_tokenId];
    }

    /// @dev Merge two NFTs union their balances and keep the biggest lock time.
    function merge(uint _from, uint _to) external nonReentrant {
        require(_from != _to, "IDENTICAL_ADDRESS");
        require(!isAlwaysMaxLock[_from] && !isAlwaysMaxLock[_to], "ALWAYS_MAX_LOCK");
        require(isApprovedOrOwner(msg.sender, _from) && isApprovedOrOwner(msg.sender, _to), "NOT_OWNER");

        uint lockedEndFrom = lockedEnd(_from);
        uint lockedEndTo = lockedEnd(_to);
        require(lockedEndFrom > block.timestamp && lockedEndTo > block.timestamp, "EXPIRED");
        uint end = lockedEndFrom >= lockedEndTo ? lockedEndFrom : lockedEndTo;
        uint oldDerivedAmount = lockedDerivedAmount[_from];

        uint length = tokens.length;
        // we should use the old one for properly calculate checkpoint for the new ve
        uint newLockedEndTo = lockedEndTo;
        for (uint i; i < length; i++) {
            address stakingToken = tokens[i];
            uint _lockedAmountFrom = lockedAmounts[_from][stakingToken];
            if (_lockedAmountFrom == 0) {
                continue;
            }
            lockedAmounts[_from][stakingToken] = 0;

            _depositFor(
                DepositInfo({
                    stakingToken: stakingToken,
                    tokenId: _to,
                    value: _lockedAmountFrom,
                    unlockTime: end,
                    lockedAmount: lockedAmounts[_to][stakingToken],
                    lockedDerivedAmount: lockedDerivedAmount[_to],
                    lockedEnd: newLockedEndTo,
                    depositType: DepositType.MERGE_TYPE
                })
            );

            // set new lock time to the current end lock
            newLockedEndTo = end;

            emit Merged(stakingToken, msg.sender, _from, _to);
        }

        _updateLockedDerivedAmount(_from, 0);
        _lockedEndReal[_from] = 0;

        // update checkpoint
        _checkpoint(CheckpointInfo(_from, oldDerivedAmount, 0, lockedEndFrom, lockedEndFrom, isAlwaysMaxLock[_from]));

        _burn(_from);
    }

    /// @dev Split given veNFT. A new NFT will have a given percent of underlying tokens.
    /// @param _tokenId ve token ID
    /// @param percent percent of underlying tokens for new NFT with denominator 1e18 (1-(100e18-1)).
    function split(uint _tokenId, uint percent) external nonReentrant {
        require(!isAlwaysMaxLock[_tokenId], "ALWAYS_MAX_LOCK");
        require(isApprovedOrOwner(msg.sender, _tokenId), "NOT_OWNER");
        require(percent != 0 && percent < 100e18, "WRONG_INPUT");

        uint _lockedDerivedAmount = lockedDerivedAmount[_tokenId];
        uint oldLockedDerivedAmount = _lockedDerivedAmount;
        uint _lockedEnd = lockedEnd(_tokenId);

        require(_lockedEnd > block.timestamp, "EXPIRED");

        // crete new NFT
        uint _newTokenId = _incrementTokenIdAndGet();
        _mint(msg.sender, _newTokenId);

        // migrate percent of locked tokens to the new NFT
        uint length = tokens.length;
        for (uint i; i < length; ++i) {
            address stakingToken = tokens[i];
            uint _lockedAmount = lockedAmounts[_tokenId][stakingToken];
            if (_lockedAmount == 0) {
                continue;
            }
            uint amountForNewNFT = _lockedAmount * percent / 100e18;
            require(amountForNewNFT != 0, "LOW_PERCENT");

            uint newLockedDerivedAmount = VeSTGNLib.calculateDerivedAmount(
                _lockedAmount,
                _lockedDerivedAmount,
                _lockedAmount - amountForNewNFT,
                tokenWeights[stakingToken],
                IERC20Metadata(stakingToken).decimals()
            );

            _lockedDerivedAmount = newLockedDerivedAmount;

            lockedAmounts[_tokenId][stakingToken] = _lockedAmount - amountForNewNFT;

            // increase values for new NFT
            _depositFor(
                DepositInfo({
                    stakingToken: stakingToken,
                    tokenId: _newTokenId,
                    value: amountForNewNFT,
                    unlockTime: _lockedEnd,
                    lockedAmount: 0,
                    lockedDerivedAmount: lockedDerivedAmount[_newTokenId],
                    lockedEnd: _lockedEnd,
                    depositType: DepositType.MERGE_TYPE
                })
            );
        }

        _updateLockedDerivedAmount(_tokenId, _lockedDerivedAmount);

        // update checkpoint
        _checkpoint(
            CheckpointInfo(
                _tokenId,
                oldLockedDerivedAmount,
                _lockedDerivedAmount,
                _lockedEnd,
                _lockedEnd,
                isAlwaysMaxLock[_tokenId]
            )
        );

        emit Split(_tokenId, _newTokenId, percent);
    }

    /// @notice Withdraw all staking tokens for `_tokenId`
    /// @dev Only possible if the lock has expired
    function withdrawAll(uint _tokenId) external {
        uint length = tokens.length;
        for (uint i; i < length; ++i) {
            address token = tokens[i];
            if (lockedAmounts[_tokenId][token] != 0) {
                withdraw(token, _tokenId);
            }
        }
    }

    /// @notice Withdraw given staking token for `_tokenId`
    /// @dev Only possible if the lock has expired
    function withdraw(address stakingToken, uint _tokenId) public nonReentrant {
        require(isApprovedOrOwner(msg.sender, _tokenId), "NOT_OWNER");

        (uint oldLockedAmount, uint oldLockedDerivedAmount, uint oldLockedEnd) = _lockInfo(stakingToken, _tokenId);
        require(block.timestamp >= oldLockedEnd, "NOT_EXPIRED");
        require(oldLockedAmount > 0, "ZERO_LOCKED");
        require(!isAlwaysMaxLock[_tokenId], "ALWAYS_MAX_LOCK");

        uint newLockedDerivedAmount = VeSTGNLib.calculateDerivedAmount(
            oldLockedAmount,
            oldLockedDerivedAmount,
            0,
            tokenWeights[stakingToken],
            IERC20Metadata(stakingToken).decimals()
        );

        // if no tokens set lock to zero
        uint newLockEnd = oldLockedEnd;
        if (newLockedDerivedAmount == 0) {
            _lockedEndReal[_tokenId] = 0;
            newLockEnd = 0;
        }

        // update derived amount
        _updateLockedDerivedAmount(_tokenId, newLockedDerivedAmount);

        // set locked amount to zero, we will withdraw all
        lockedAmounts[_tokenId][stakingToken] = 0;

        // update checkpoint
        _checkpoint(
            CheckpointInfo(
                _tokenId,
                oldLockedDerivedAmount,
                newLockedDerivedAmount,
                oldLockedEnd,
                newLockEnd,
                false // already checked and can not be true
            )
        );

        // Burn the NFT
        if (newLockedDerivedAmount == 0) {
            _burn(_tokenId);
        }

        emit Withdraw(stakingToken, msg.sender, _tokenId, oldLockedAmount, block.timestamp);
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //                             Attention!
    // The following ERC20/minime-compatible methods are not real balanceOf and supply!
    // They measure the weights for the purpose of voting, so they don't represent
    // real coins.
    /////////////////////////////////////////////////////////////////////////////////////

    /// @notice Get the current voting power for `_tokenId`
    /// @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
    /// @param _tokenId NFT for lock
    /// @param _t Epoch time to return voting power at
    /// @return User voting power
    function _balanceOfNFT(uint _tokenId, uint _t) internal view returns (uint) {
        // with max lock return balance as is
        if (isAlwaysMaxLock[_tokenId]) {
            return lockedDerivedAmount[_tokenId];
        }

        uint _epoch = userPointEpoch[_tokenId];
        if (_epoch == 0) {
            return 0;
        } else {
            Point memory lastPoint = _userPointHistory[_tokenId][_epoch];
            require(_t >= lastPoint.ts, "WRONG_INPUT");
            lastPoint.bias -= lastPoint.slope * int128(int(_t) - int(lastPoint.ts));
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
            return uint(int(lastPoint.bias));
        }
    }

    /// @dev Returns current token URI metadata
    /// @param _tokenId Token ID to fetch URI for.
    function tokenURI(uint _tokenId) external view override returns (string memory) {
        require(_idToOwner[_tokenId] != address(0), "TOKEN_NOT_EXIST");

        uint _lockedEnd = lockedEnd(_tokenId);
        return VeSTGNLib.tokenURI(
            _tokenId,
            uint(int(lockedDerivedAmount[_tokenId])),
            block.timestamp < _lockedEnd ? _lockedEnd - block.timestamp : 0,
            _balanceOfNFT(_tokenId, block.timestamp)
        );
    }

    /// @notice Measure voting power of `_tokenId` at block height `_block`
    /// @dev Adheres to MiniMe `balanceOfAt` interface: https://github.com/Giveth/minime
    /// @param _tokenId User's wallet NFT
    /// @param _block Block to calculate the voting power at
    /// @return Voting power
    function _balanceOfAtNFT(uint _tokenId, uint _block) internal view returns (uint) {
        // for always max lock just return full derived amount
        if (isAlwaysMaxLock[_tokenId]) {
            return lockedDerivedAmount[_tokenId];
        }

        return VeSTGNLib.balanceOfAtNFT(_tokenId, _block, epoch, userPointEpoch, _userPointHistory, _pointHistory);
    }

    /// @notice Calculate total voting power
    /// @dev Adheres to the ERC20 `totalSupply` interface for Aragon compatibility
    /// @return Total voting power
    function totalSupplyAtT(uint t) public view returns (uint) {
        uint _epoch = epoch;
        Point memory lastPoint = _pointHistory[_epoch];
        return VeSTGNLib.supplyAt(lastPoint, t, slopeChanges) + additionalTotalSupply;
    }

    /// @notice Calculate total voting power at some point in the past
    /// @param _block Block to calculate the total voting power at
    /// @return Total voting power at `_block`
    function totalSupplyAt(uint _block) external view override returns (uint) {
        return VeSTGNLib.totalSupplyAt(_block, epoch, _pointHistory, slopeChanges) + additionalTotalSupply;
    }

    /// @notice Record global data to checkpoint
    function checkpoint() external override {
        _checkpoint(CheckpointInfo(0, 0, 0, 0, 0, false));
    }

    /// @notice Record global and per-user data to checkpoint
    function _checkpoint(CheckpointInfo memory info) internal {
        // we do not need checkpoints for always max lock
        if (info.isAlwaysMaxLock) {
            return;
        }

        uint _epoch = epoch;
        uint newEpoch = VeSTGNLib.checkpoint(
            info.tokenId,
            info.oldDerivedAmount,
            info.newDerivedAmount,
            info.oldEnd,
            info.newEnd,
            _epoch,
            slopeChanges,
            userPointEpoch,
            _userPointHistory,
            _pointHistory
        );

        if (newEpoch != 0 && newEpoch != _epoch) {
            epoch = newEpoch;
        }
    }

    function _burn(uint _tokenId) internal {
        address owner = ownerOf(_tokenId);
        // Clear approval
        approve(address(0), _tokenId);
        // Remove token
        _removeTokenFrom(owner, _tokenId);
        emit Transfer(owner, address(0), _tokenId);
    }
}
