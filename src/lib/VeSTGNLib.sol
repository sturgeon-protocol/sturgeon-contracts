// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/utils/Base64.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../interfaces/IVe.sol";

/// @title Library with additional ve functions
/// @author belbix
/// @author a17
library VeSTGNLib {
    using Math for uint;

    uint internal constant WEEK = 1 weeks;
    uint internal constant MULTIPLIER = 1 ether;
    int128 internal constant I_MAX_TIME = 16 weeks;
    uint internal constant WEIGHT_DENOMINATOR = 100e18;

    // Only for internal usage
    struct CheckpointInfo {
        uint tokenId;
        uint oldDerivedAmount;
        uint newDerivedAmount;
        uint oldEnd;
        uint newEnd;
        uint epoch;
        IVe.Point uOld;
        IVe.Point uNew;
        int128 oldDSlope;
        int128 newDSlope;
    }

    ////////////////////////////////////////////////////
    //  MAIN LOGIC
    ////////////////////////////////////////////////////

    function calculateDerivedAmount(
        uint currentAmount,
        uint oldDerivedAmount,
        uint newAmount,
        uint weight,
        uint8 decimals
    ) internal pure returns (uint) {
        // subtract current derived balance
        // rounded to UP for subtracting closer to 0 value
        if (oldDerivedAmount != 0 && currentAmount != 0) {
            currentAmount = currentAmount.mulDiv(1e18, 10 ** decimals, Math.Rounding.Ceil);
            uint currentDerivedAmount = currentAmount.mulDiv(weight, WEIGHT_DENOMINATOR, Math.Rounding.Ceil);
            if (oldDerivedAmount > currentDerivedAmount) {
                oldDerivedAmount -= currentDerivedAmount;
            } else {
                // in case of wrong rounding better to set to zero than revert
                oldDerivedAmount = 0;
            }
        }

        // recalculate derived amount with new amount
        // rounded to DOWN
        // normalize decimals to 18
        newAmount = newAmount.mulDiv(1e18, 10 ** decimals, Math.Rounding.Floor);
        // calculate the final amount based on the weight
        newAmount = newAmount.mulDiv(weight, WEIGHT_DENOMINATOR, Math.Rounding.Floor);
        return oldDerivedAmount + newAmount;
    }

    /// @notice Binary search to estimate timestamp for block number
    /// @param _block Block to find
    /// @param maxEpoch Don't go beyond this epoch
    /// @return Approximate timestamp for block
    function findBlockEpoch(
        uint _block,
        uint maxEpoch,
        mapping(uint => IVe.Point) storage _pointHistory
    ) public view returns (uint) {
        // Binary search
        uint _min = 0;
        uint _max = maxEpoch;
        for (uint i = 0; i < 128; ++i) {
            // Will be always enough for 128-bit numbers
            if (_min >= _max) {
                break;
            }
            uint _mid = (_min + _max + 1) / 2;
            if (_pointHistory[_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    /// @notice Measure voting power of `_tokenId` at block height `_block`
    /// @return Voting power
    function balanceOfAtNFT(
        uint _tokenId,
        uint _block,
        uint maxEpoch,
        mapping(uint => uint) storage userPointEpoch,
        mapping(uint => IVe.Point[1000000000]) storage _userPointHistory,
        mapping(uint => IVe.Point) storage _pointHistory
    ) external view returns (uint) {
        // Copying and pasting totalSupply code because Vyper cannot pass by
        // reference yet
        require(_block <= block.number, "WRONG_INPUT");

        // Binary search
        uint _min = 0;
        uint _max = userPointEpoch[_tokenId];
        for (uint i = 0; i < 128; ++i) {
            // Will be always enough for 128-bit numbers
            if (_min >= _max) {
                break;
            }
            uint _mid = (_min + _max + 1) / 2;
            if (_userPointHistory[_tokenId][_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }

        IVe.Point memory uPoint = _userPointHistory[_tokenId][_min];

        uint _epoch = findBlockEpoch(_block, maxEpoch, _pointHistory);
        IVe.Point memory point0 = _pointHistory[_epoch];
        uint dBlock = 0;
        uint dt = 0;
        if (_epoch < maxEpoch) {
            IVe.Point memory point1 = _pointHistory[_epoch + 1];
            dBlock = point1.blk - point0.blk;
            dt = point1.ts - point0.ts;
        } else {
            dBlock = block.number - point0.blk;
            dt = block.timestamp - point0.ts;
        }
        uint blockTime = point0.ts;
        if (dBlock != 0 && _block > point0.blk) {
            blockTime += (dt * (_block - point0.blk)) / dBlock;
        }

        uPoint.bias -= uPoint.slope * int128(int(blockTime - uPoint.ts));
        return uint(uint128(_positiveInt128(uPoint.bias)));
    }

    /// @notice Calculate total voting power at some point in the past
    /// @param point The point (bias/slope) to start search from
    /// @param t Time to calculate the total voting power at
    /// @return Total voting power at that time
    function supplyAt(
        IVe.Point memory point,
        uint t,
        mapping(uint => int128) storage slopeChanges
    ) public view returns (uint) {
        IVe.Point memory lastPoint = point;
        uint ti = (lastPoint.ts / WEEK) * WEEK;
        for (uint i = 0; i < 255; ++i) {
            ti += WEEK;
            int128 dSlope = 0;
            if (ti > t) {
                ti = t;
            } else {
                dSlope = slopeChanges[ti];
            }
            lastPoint.bias -= lastPoint.slope * int128(int(ti - lastPoint.ts));
            if (ti == t) {
                break;
            }
            lastPoint.slope += dSlope;
            lastPoint.ts = ti;
        }
        return uint(uint128(_positiveInt128(lastPoint.bias)));
    }

    /// @notice Calculate total voting power at some point in the past
    /// @param _block Block to calculate the total voting power at
    /// @return Total voting power at `_block`
    function totalSupplyAt(
        uint _block,
        uint _epoch,
        mapping(uint => IVe.Point) storage _pointHistory,
        mapping(uint => int128) storage slopeChanges
    ) external view returns (uint) {
        require(_block <= block.number, "WRONG_INPUT");

        uint targetEpoch = findBlockEpoch(_block, _epoch, _pointHistory);

        IVe.Point memory point = _pointHistory[targetEpoch];
        // it is possible only for a block before the launch
        // return 0 as more clear answer than revert
        if (point.blk > _block) {
            return 0;
        }
        uint dt = 0;
        if (targetEpoch < _epoch) {
            IVe.Point memory pointNext = _pointHistory[targetEpoch + 1];
            // next point block can not be the same or lower
            dt = ((_block - point.blk) * (pointNext.ts - point.ts)) / (pointNext.blk - point.blk);
        } else {
            if (point.blk != block.number) {
                dt = ((_block - point.blk) * (block.timestamp - point.ts)) / (block.number - point.blk);
            }
        }
        // Now dt contains info on how far are we beyond point
        return supplyAt(point, point.ts + dt, slopeChanges);
    }

    /// @notice Record global and per-user data to checkpoint
    function checkpoint(
        uint tokenId,
        uint oldDerivedAmount,
        uint newDerivedAmount,
        uint oldEnd,
        uint newEnd,
        uint epoch,
        mapping(uint => int128) storage slopeChanges,
        mapping(uint => uint) storage userPointEpoch,
        mapping(uint => IVe.Point[1000000000]) storage _userPointHistory,
        mapping(uint => IVe.Point) storage _pointHistory
    ) external returns (uint newEpoch) {
        IVe.Point memory uOld;
        IVe.Point memory uNew;
        return _checkpoint(
            CheckpointInfo({
                tokenId: tokenId,
                oldDerivedAmount: oldDerivedAmount,
                newDerivedAmount: newDerivedAmount,
                oldEnd: oldEnd,
                newEnd: newEnd,
                epoch: epoch,
                uOld: uOld,
                uNew: uNew,
                oldDSlope: 0,
                newDSlope: 0
            }),
            slopeChanges,
            userPointEpoch,
            _userPointHistory,
            _pointHistory
        );
    }

    function _checkpoint(
        CheckpointInfo memory info,
        mapping(uint => int128) storage slopeChanges,
        mapping(uint => uint) storage userPointEpoch,
        mapping(uint => IVe.Point[1000000000]) storage _userPointHistory,
        mapping(uint => IVe.Point) storage _pointHistory
    ) internal returns (uint newEpoch) {
        if (info.tokenId != 0) {
            // Calculate slopes and biases
            // Kept at zero when they have to
            if (info.oldEnd > block.timestamp && info.oldDerivedAmount > 0) {
                info.uOld.slope = int128(uint128(info.oldDerivedAmount)) / I_MAX_TIME;
                info.uOld.bias = info.uOld.slope * int128(int(info.oldEnd - block.timestamp));
            }
            if (info.newEnd > block.timestamp && info.newDerivedAmount > 0) {
                info.uNew.slope = int128(uint128(info.newDerivedAmount)) / I_MAX_TIME;
                info.uNew.bias = info.uNew.slope * int128(int(info.newEnd - block.timestamp));
            }

            // Read values of scheduled changes in the slope
            // oldLocked.end can be in the past and in the future
            // newLocked.end can ONLY by in the FUTURE unless everything expired: than zeros
            info.oldDSlope = slopeChanges[info.oldEnd];
            if (info.newEnd != 0) {
                if (info.newEnd == info.oldEnd) {
                    info.newDSlope = info.oldDSlope;
                } else {
                    info.newDSlope = slopeChanges[info.newEnd];
                }
            }
        }

        IVe.Point memory lastPoint = IVe.Point({bias: 0, slope: 0, ts: block.timestamp, blk: block.number});
        if (info.epoch > 0) {
            lastPoint = _pointHistory[info.epoch];
        }
        uint lastCheckpoint = lastPoint.ts;
        // initialLastPoint is used for extrapolation to calculate block number
        // (approximately, for *At methods) and save them
        // as we cannot figure that out exactly from inside the contract
        IVe.Point memory initialLastPoint = lastPoint;
        uint blockSlope = 0;
        // dblock/dt
        if (block.timestamp > lastPoint.ts) {
            blockSlope = (MULTIPLIER * (block.number - lastPoint.blk)) / (block.timestamp - lastPoint.ts);
        }
        // If last point is already recorded in this block, slope=0
        // But that's ok b/c we know the block in such case

        // Go over weeks to fill history and calculate what the current point is
        {
            uint ti = (lastCheckpoint / WEEK) * WEEK;
            // Hopefully it won't happen that this won't get used in 5 years!
            // If it does, users will be able to withdraw but vote weight will be broken
            for (uint i = 0; i < 255; ++i) {
                ti += WEEK;
                int128 dSlope = 0;
                if (ti > block.timestamp) {
                    ti = block.timestamp;
                } else {
                    dSlope = slopeChanges[ti];
                }
                lastPoint.bias = _positiveInt128(lastPoint.bias - lastPoint.slope * int128(int(ti - lastCheckpoint)));
                lastPoint.slope = _positiveInt128(lastPoint.slope + dSlope);
                lastCheckpoint = ti;
                lastPoint.ts = ti;
                lastPoint.blk = initialLastPoint.blk + (blockSlope * (ti - initialLastPoint.ts)) / MULTIPLIER;
                info.epoch += 1;
                if (ti == block.timestamp) {
                    lastPoint.blk = block.number;
                    break;
                } else {
                    _pointHistory[info.epoch] = lastPoint;
                }
            }
        }

        newEpoch = info.epoch;
        // Now pointHistory is filled until t=now

        if (info.tokenId != 0) {
            // If last point was in this block, the slope change has been applied already
            // But in such case we have 0 slope(s)
            lastPoint.slope = _positiveInt128(lastPoint.slope + (info.uNew.slope - info.uOld.slope));
            lastPoint.bias = _positiveInt128(lastPoint.bias + (info.uNew.bias - info.uOld.bias));
        }

        // Record the changed point into history
        _pointHistory[info.epoch] = lastPoint;

        if (info.tokenId != 0) {
            // Schedule the slope changes (slope is going down)
            // We subtract newUserSlope from [newLocked.end]
            // and add old_user_slope to [old_locked.end]
            if (info.oldEnd > block.timestamp) {
                // old_dslope was <something> - u_old.slope, so we cancel that
                info.oldDSlope += info.uOld.slope;
                if (info.newEnd == info.oldEnd) {
                    info.oldDSlope -= info.uNew.slope;
                    // It was a new deposit, not extension
                }
                slopeChanges[info.oldEnd] = info.oldDSlope;
            }

            if (info.newEnd > block.timestamp) {
                if (info.newEnd > info.oldEnd) {
                    info.newDSlope -= info.uNew.slope;
                    // old slope disappeared at this point
                    slopeChanges[info.newEnd] = info.newDSlope;
                }
                // else: we recorded it already in oldDSlope
            }
            // Now handle user history
            uint userEpoch = userPointEpoch[info.tokenId] + 1;

            userPointEpoch[info.tokenId] = userEpoch;
            info.uNew.ts = block.timestamp;
            info.uNew.blk = block.number;
            _userPointHistory[info.tokenId][userEpoch] = info.uNew;
        }
    }

    function _positiveInt128(int128 value) internal pure returns (int128) {
        return value < 0 ? int128(0) : value;
    }

    /// @dev Return SVG logo of veTETU.
    function tokenURI(
        uint _tokenId,
        uint _balanceOf,
        uint untilEnd,
        uint _value
    ) public pure returns (string memory output) {
        output =
            '<svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 2406.2 3609.2" style="enable-background:new 0 0 2406.2 3609.2;" xml:space="preserve"><style>.st0 {fill:#101035;}.st1 {fill:#5E78F7;}.st2 {font-family:"TimesNewRomanPS-BoldMT";}.st3 {font-size:189px;}.st4 {fill:#FFFFFF;}.st5 {font-family:"TimesNewRomanPSMT";}.st6 {font-size:164.1369px;}.st7 {fill:#212E6D;}.st8 {fill:#3D68D3;}</style><rect class="st0" width="2406.2" height="3609.2"/>';

        output = string(
            abi.encodePacked(
                output,
                '<text transform="matrix(1 0 0 1 201.4935 1860.8424)" class="st1 st2 st3">ID:</text><text transform="matrix(1 0 0 1 201.4935 2029.2721)" class="st4 st5 st6">',
                _u2s(_tokenId),
                "</text>"
            )
        );
        output = string(
            abi.encodePacked(
                output,
                '<text transform="matrix(1 0 0 1 201.4935 2325.1277)" class="st1 st2 st3">Balance:</text><text transform="matrix(1 0 0 1 201.4935 2493.5593)" class="st4 st5 st6">',
                _u2s(_balanceOf / 1e18),
                "</text>"
            )
        );
        output = string(
            abi.encodePacked(
                output,
                '<text transform="matrix(1 0 0 1 201.4935 2789.4148)" class="st1 st2 st3">Locked end:</text><text transform="matrix(1 0 0 1 201.4935 2957.8464)" class="st4 st5 st6">',
                _u2s(untilEnd / 60 / 60 / 24),
                " days</text>"
            )
        );
        output = string(
            abi.encodePacked(
                output,
                '<text transform="matrix(1 0 0 1 201.4935 3253.7)" class="st1 st2 st3">Value:</text><text transform="matrix(1 0 0 1 201.4935 3422.1316)" class="st4 st5 st6">',
                _u2s(_value / 1e18),
                "</text>"
            )
        );

        output = string(
            abi.encodePacked(
                output,
                '<g><circle class="st0" cx="1501.6" cy="901" r="762.5"/><path class="st7" d="M1201,331.2c-9.6,0-18.8-5.3-23.4-14.4c-6.5-12.9-1.3-28.7,11.6-35.2c47.5-24,97.7-42.5,149.3-54.9 c53.1-12.8,108-19.3,163.1-19.3c54.9,0,109.6,6.4,162.5,19.1c51.4,12.3,101.5,30.7,148.8,54.5c12.9,6.5,18.1,22.3,11.6,35.2 c-6.5,12.9-22.3,18.1-35.2,11.6c-43.7-22-90-38.9-137.5-50.3c-48.9-11.7-99.4-17.7-150.2-17.7c-51,0-101.8,6-150.9,17.8 c-47.7,11.5-94.1,28.6-138,50.7C1209,330.3,1205,331.2,1201,331.2z"/> <path class="st1" d="M1501.6,1594.7c-93.6,0-184.5-18.3-270-54.5c-82.6-34.9-156.8-84.9-220.5-148.6S897.4,1253.6,862.5,1171 c-36.2-85.5-54.5-176.4-54.5-270c0-56.7,6.9-113,20.4-167.5c13.1-52.9,32.6-104.4,57.9-152.8c49.5-95,121.6-178.5,208.5-241.5 c11.7-8.5,28.1-5.9,36.6,5.8c8.5,11.7,5.9,28.1-5.8,36.6c-80.4,58.3-147,135.5-192.8,223.3c-23.3,44.8-41.3,92.3-53.5,141.2 c-12.5,50.4-18.8,102.5-18.8,154.9c0,86.6,17,170.6,50.4,249.6c32.3,76.4,78.5,144.9,137.4,203.8s127.5,105.1,203.8,137.4 c79,33.4,163,50.4,249.6,50.4s170.6-17,249.6-50.4c76.4-32.3,144.9-78.5,203.8-137.4c58.9-58.9,105.1-127.5,137.4-203.8 c33.4-79,50.4-163,50.4-249.6c0-52.3-6.3-104.3-18.7-154.6c-12.1-48.8-30-96.2-53.2-140.9c-45.6-87.6-112-164.8-192-223.1 c-11.7-8.5-14.3-24.9-5.7-36.6c8.5-11.7,24.9-14.3,36.6-5.7c86.5,63.1,158.3,146.5,207.6,241.3c25.2,48.4,44.5,99.7,57.6,152.5 c13.5,54.4,20.3,110.6,20.3,167.2c0,93.6-18.3,184.5-54.5,270c-34.9,82.6-84.9,156.8-148.6,220.5s-137.9,113.7-220.5,148.6 C1686.1,1576.3,1595.2,1594.7,1501.6,1594.7z"/> <path class="st8" d="M1650.9,1524.8c15.2,10.4,37.8,25.8,56.9,38.7c21.6-6.7,42.9-14.5,63.9-23.4c20.7-8.7,41-18.5,60.8-29.3 c-9.4-12.3-19.9-27.1-30.1-43.3c-16.7,8.9-33.8,17-51.1,24.4C1718.6,1505.7,1685.1,1516.7,1650.9,1524.8z"/> <g> <path class="st7" d="M1226.2,712.5c8.5-7.8,18.6-14.8,29.9-21.1c-1.1,22.4,1.6,48.5,12.2,75.7c30.7,79,63.2,117.2,94.3,117.8 c13.6,0.3,64.8-15.8,105.5-14c40.7,1.8,26.2,17.1,7.9,28.9c-18.3,11.8-6,35.9,34.1,60.1s64.3,10.6,95.6,0 c31.3-10.6,55.3-17.1,44.2-2.4c-11.1,14.8-41.8,34.2-41.2,55.4c0.6,21.2,21.7,92,50.9,117c9.1,7.8-27.9,11.2-74.5-44.8 s-44.2-117.4-131.6-112c-87.3,5.3-36,69-44.8,76.7c-8.8,7.7-43.8-36.4-61.5-70c-8.8-16.8-11.3-39.4-22.9-49.8s-44-18.4-60.2-23.2 c-61.3-18.5-85.3-50.3-85.3-50.3S1152,780.5,1226.2,712.5z"/> <path class="st7" d="M1777,1089.5c-8.5,7.8-18.6,14.8-29.9,21.1c1.1-22.4-1.6-48.5-12.2-75.7c-30.7-79-63.2-117.2-94.3-117.8 c-13.6-0.3-64.8,15.8-105.5,14c-40.7-1.8-26.2-17.1-7.9-28.9c18.3-11.8,6-35.9-34.1-60.1c-40.1-24.2-64.3-10.6-95.6,0 c-31.3,10.6-55.3,17.1-44.2,2.4c11.1-14.8,41.8-34.2,41.2-55.4c-0.6-21.2-21.7-92-50.9-117c-9.1-7.8,27.9-11.2,74.5,44.8 s44.2,117.4,131.6,112c87.3-5.3,36-69,44.8-76.7c8.8-7.7,43.8,36.4,61.5,70c8.8,16.8,11.3,39.4,22.9,49.8 c11.6,10.4,44,18.4,60.2,23.2c61.3,18.5,85.3,50.3,85.3,50.3S1851.2,1021.5,1777,1089.5z"/> <path class="st1" d="M1880.1,1267.3c-40.4,85.7-89,106.2-146.3,131.1c-57.3,24.9-103,25.6-105.6,27.2c-2.6,1.5,2.1,4.1,19.7,7.9 c17.6,3.8,34.5,0.3,59.5-1.2c25-1.6,55.7,28.9,82.1,75.6c26.4,46.7,42.2,48.6,35.3,59c-6.9,10.3-25.3,9.9-81-17.5 c-55.7-27.4-66.3-46.2-105.7-78.8c-39.4-32.6-28.6-26.4-86.1-22.3c-57.5,4.2-170.1-9.8-271.6-45.5 c-101.5-35.7-176.3-78.6-176.3-90.8c0-12.2,24.7-7,52.4-7.4c27.7-0.4,65.3-24.3,125.2-64.5c1-0.7,2-1.3,3-2 c45.5-36.9,94.7-74.2,109.9-85.6c2.9-2.2,6.8-2.6,10-1l40.8,19.7c3.3,1.6,7.3,1.2,10.2-1.1l30.6-23.9c2.9-2.3,6.8-2.7,10.1-1.1 l33.4,15.8c3.3,1.5,7.1,1.1,10-1l32.5-24.7c2.8-2.1,6.5-2.6,9.7-1.2l35.1,15.4c3.2,1.4,6.9,1,9.7-1.1l27.3-20.5 c2.5-1.9,5.8-2.5,8.8-1.5c6.3,2.1,17.5,5.7,25.5,7.4c1.7,0.4,3.4,0.2,5.1-0.3c19.6-6.4,37.8-14,53.7-22.9 c11.3-6.3,21.4-13.3,29.9-21.1c74.2-68,47.3-144,47.3-144C1929.1,1074.5,1899.3,1226.4,1880.1,1267.3z"/> <path class="st1" d="M1123.2,534.8c40.4-85.7,89-106.2,146.3-131.1c57.3-24.9,103-25.6,105.6-27.2c2.6-1.5-2.1-4.1-19.7-7.9 c-17.6-3.8-34.5-0.3-59.5,1.2c-25,1.6-55.7-28.9-82.1-75.6c-26.4-46.7-42.2-48.6-35.3-59c6.9-10.3,25.3-9.9,81,17.5 c55.7,27.4,66.3,46.2,105.7,78.8c39.4,32.6,28.6,26.4,86.1,22.3c57.5-4.2,170.1,9.8,271.6,45.5c101.5,35.7,176.3,78.6,176.3,90.8 c0,12.2-24.7,7-52.4,7.4c-27.7,0.4-65.3,24.3-125.2,64.5c-1,0.7-2,1.3-3,2c-45.5,36.9-94.7,74.2-109.9,85.6c-2.9,2.2-6.8,2.6-10,1 l-40.8-19.7c-3.3-1.6-7.3-1.2-10.2,1.1l-30.6,23.9c-2.9,2.3-6.8,2.7-10.1,1.1l-33.4-15.8c-3.3-1.5-7.1-1.1-10,1l-32.5,24.7 c-2.8,2.1-6.5,2.6-9.7,1.2l-35.1-15.4c-3.2-1.4-6.9-1-9.7,1.1l-27.3,20.5c-2.5,1.9-5.8,2.5-8.8,1.5c-6.3-2.1-17.5-5.7-25.5-7.4 c-1.7-0.4-3.4-0.2-5.1,0.3c-19.6,6.4-37.8,14-53.7,22.9c-11.3,6.3-21.4,13.3-29.9,21.1c-74.2,68-47.3,144-47.3,144 C1074.1,727.5,1103.9,575.6,1123.2,534.8z"/> </g> <g> <g> <path class="st7" d="M2020.3,642.8c3.2,0,3.2-5,0-5C2017.1,637.8,2017.1,642.8,2020.3,642.8L2020.3,642.8z"/> </g> </g></g></svg>'
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "veSTGN #',
                        Strings.toString(_tokenId),
                        '", "description": "Locked STGN tokens", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '"}'
                    )
                )
            )
        );
        output = string(abi.encodePacked("data:application/json;base64,", json));
    }

    function _u2s(uint num) internal pure returns (string memory) {
        return Strings.toString(num);
    }
}
