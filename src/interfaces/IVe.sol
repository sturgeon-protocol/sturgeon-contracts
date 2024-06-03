// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface IVe is IERC721Metadata {
    enum DepositType {
        DEPOSIT_FOR_TYPE,
        CREATE_LOCK_TYPE,
        INCREASE_LOCK_AMOUNT,
        INCREASE_UNLOCK_TIME,
        MERGE_TYPE
    }

    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint ts;
        uint blk; // block
    }
    /* We cannot really do block numbers per se b/c slope is per time, not per block
    * and per block could be fairly bad b/c Ethereum changes blocktimes.
    * What we can do is to extrapolate ***At functions */

    function lockedAmounts(uint veId, address stakingToken) external view returns (uint);

    function lockedDerivedAmount(uint veId) external view returns (uint);

    function lockedEnd(uint veId) external view returns (uint);

    function tokens(uint idx) external view returns (address);

    function balanceOfNFT(uint) external view returns (uint);

    function isApprovedOrOwner(address, uint) external view returns (bool);

    function createLockFor(address _token, uint _value, uint _lockDuration, address _to) external returns (uint);

    function userPointEpoch(uint tokenId) external view returns (uint);

    function epoch() external view returns (uint);

    function userPointHistory(uint tokenId, uint loc) external view returns (Point memory);

    function pointHistory(uint loc) external view returns (Point memory);

    function checkpoint() external;

    function increaseAmount(address _token, uint _tokenId, uint _value) external;

    function totalSupplyAt(uint _block) external view returns (uint);
}
