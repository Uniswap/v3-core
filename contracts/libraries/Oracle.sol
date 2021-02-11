// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './BitMath.sol';

/// @title Oracle
/// @notice Provides price and liquidity data useful for a wide variety of system designs
/// @dev Instances of stored oracle data, "observations", are collected in the oracle array
/// Every pair is initialized with an oracle array length of 1. Anyone can pay the SSTOREs to increase the
/// maximum length of the oracle array. New slots will be added when the array is fully populated.
/// Observations are overwritten when the full length of the oracle array is populated.
/// The most recent observation is available, independent of the length of the oracle array, by passing 0 to observe()
library Oracle {
    struct Observation {
        // the block timestamp of the observation
        uint32 blockTimestamp;
        // the tick accumulator, i.e. tick * time elapsed since the pair was first initialized
        int56 tickCumulative;
        // the liquidity accumulator, i.e. log base 2 of liquidity * time elapsed since the pair was first initialized
        // the most significant 39 bits are the value, the least significant bit is whether the observation is initialized
        uint40 liquidityCumulative;
    }

    // Two observations packed in a single storage slot
    struct PackedObservation {
        uint32 blockTimestamp0;
        int56 tickCumulative0;
        uint40 liquidityCumulative0;
        uint32 blockTimestamp1;
        int56 tickCumulative1;
        uint40 liquidityCumulative1;
    }

    // @dev Return the most significant bit of liquidity in the range of 1-127 so as to only use 7 bits
    function liquidityBit(uint128 liquidity) private pure returns (uint8 msb) {
        if ((msb = BitMath.mostSignificantBit(uint256(liquidity) + 1)) > 127) {
            msb = 127;
        }
    }

    /// @notice Transforms a previous observation into a new observation, given the passage of time and the current tick and liquidity values
    /// @dev blockTimestamp _must_ be chronologically equal to or greater than last.blockTimestamp, safe for 0 or 1 overflows
    /// @param last The specified observation to be transformed
    /// @param blockTimestamp The timestamp of the new observation
    /// @param tick The active tick at the time of the new observation
    /// @param liquidityMostSignificantBit The result of #liquidityBit of the total in-range liquidity at the time of the new observation
    /// @return Observation The newly populated observation
    function transform(
        Observation memory last,
        uint32 blockTimestamp,
        int24 tick,
        uint8 liquidityMostSignificantBit
    ) private pure returns (Observation memory) {
        uint32 delta = blockTimestamp - last.blockTimestamp;
        return
            Observation({
                blockTimestamp: blockTimestamp,
                tickCumulative: last.tickCumulative + int56(tick) * delta,
                liquidityCumulative: 1 +
                    (((last.liquidityCumulative >> 1) + (uint40(liquidityMostSignificantBit) * delta)) << 1)
            });
    }

    /// @notice Initialize the oracle array by writing the first slot. Called once for the lifecycle of the observations array
    /// @param self The stored oracle array
    /// @param time The time of the oracle initialization, via block.timestamp truncated to uint32
    /// @return cardinality The number of populated elements in the oracle array
    /// @return cardinalityNext The new length of the oracle array, independent of population
    function initialize(PackedObservation[32768] storage self, uint32 time)
        internal
        returns (uint16 cardinality, uint16 cardinalityNext)
    {
        self[0] = PackedObservation({
            blockTimestamp0: time,
            tickCumulative0: 0,
            liquidityCumulative0: 1,
            blockTimestamp1: 0,
            tickCumulative1: 0,
            liquidityCumulative1: 0
        });
        return (1, 1);
    }

    function get(PackedObservation[32768] storage self, uint16 index) internal view returns (Observation memory) {
        PackedObservation memory packed = self[index / 2];
        return
            index % 2 == 0
                ? Observation({
                    blockTimestamp: packed.blockTimestamp0,
                    tickCumulative: packed.tickCumulative0,
                    liquidityCumulative: packed.liquidityCumulative0
                })
                : Observation({
                    blockTimestamp: packed.blockTimestamp1,
                    tickCumulative: packed.tickCumulative1,
                    liquidityCumulative: packed.liquidityCumulative1
                });
    }

    function put(
        PackedObservation[32768] storage self,
        uint16 index,
        Observation memory value
    ) private {
        PackedObservation memory packed = self[index / 2];
        self[index / 2] = index % 2 == 0
            ? PackedObservation({
                blockTimestamp0: value.blockTimestamp,
                tickCumulative0: value.tickCumulative,
                liquidityCumulative0: value.liquidityCumulative,
                blockTimestamp1: packed.blockTimestamp1,
                tickCumulative1: packed.tickCumulative1,
                liquidityCumulative1: packed.liquidityCumulative1
            })
            : PackedObservation({
                blockTimestamp0: packed.blockTimestamp0,
                tickCumulative0: packed.tickCumulative0,
                liquidityCumulative0: packed.liquidityCumulative0,
                blockTimestamp1: value.blockTimestamp,
                tickCumulative1: value.tickCumulative,
                liquidityCumulative1: value.liquidityCumulative
            });
    }

    /// @notice Writes an oracle observation to the array
    /// @dev Writable at most once per block. Index represents the most recently written element, and must be tracked externally.
    /// If the index is at the end of the allowable array length (according to cardinality), and the next cardinality
    /// is greater than the current one, cardinality may be increased. This restriction is created to preserve ordering.
    /// @param self The stored oracle array
    /// @param index The location of the most recently updated observation
    /// @param blockTimestamp The timestamp of the new observation
    /// @param tick The active tick at the time of the new observation
    /// @param liquidity The total in-range liquidity at the time of the new observation
    /// @param cardinality The number of populated elements in the oracle array
    /// @param cardinalityNext The new length of the oracle array, independent of population
    /// @return indexUpdated The new index of the most recently written element in the oracle array
    /// @return cardinalityUpdated The new cardinality of the oracle array
    function write(
        PackedObservation[32768] storage self,
        uint16 index,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity,
        uint16 cardinality,
        uint16 cardinalityNext
    ) internal returns (uint16 indexUpdated, uint16 cardinalityUpdated) {
        Observation memory last = get(self, index);

        // early return if we've already written an observation this block
        if (last.blockTimestamp == blockTimestamp) return (index, cardinality);

        // if the conditions are right, we can bump the cardinality
        if (cardinalityNext > cardinality && index == (cardinality - 1)) {
            cardinalityUpdated = cardinalityNext;
        } else {
            cardinalityUpdated = cardinality;
        }

        indexUpdated = (index + 1) % cardinalityUpdated;
        put(self, indexUpdated, transform(last, blockTimestamp, tick, liquidityBit(liquidity)));
    }

    /// @notice Prepares the oracle array to store up to `next` observations
    /// @param self The stored oracle array
    /// @param current The current next cardinality of the oracle array
    /// @param next The proposed next cardinality which will be populated in the oracle array
    /// @return next The next cardinality which will be populated in the oracle array
    function grow(
        PackedObservation[32768] storage self,
        uint16 current,
        uint16 next
    ) internal returns (uint16) {
        require(current > 0, 'I');
        // no-op if the passed next value isn't greater than the current next value
        if (next <= current) return current;
        // store in each slot to prevent fresh SSTOREs in swaps
        // this data will not be used because the tick is still not considered initialized
        for (uint16 i = (current % 2 == 0 ? current : current + 1); i < next; i += 2) self[i].blockTimestamp0 = 1;
        return next;
    }

    /// @notice comparator for 32-bit timestamps
    /// @dev safe for 0 or 1 overflows, a and b _must_ be chronologically before or equal to time
    /// @param time A timestamp truncated to 32 bits
    /// @param a A comparison timestamp from which to determine the relative position of `time`
    /// @param b From which to determine the relative position of `time`
    /// @return bool Whether `a` is chronologically <= `b`
    function lte(
        uint32 time,
        uint32 a,
        uint32 b
    ) private pure returns (bool) {
        // if there hasn't been overflow, no need to adjust
        if (a <= time && b <= time) return a <= b;

        uint256 aAdjusted = a > time ? a : a + 2**32;
        uint256 bAdjusted = b > time ? b : b + 2**32;

        return aAdjusted <= bAdjusted;
    }

    /// @notice Fetches the observations beforeOrAt and atOrAfter a target, i.e. where [beforeOrAt, atOrAfter] is satisfied
    /// @dev The answer must be contained in the array, used when the target is located within the stored observation
    /// boundaries: older than the most recent observation and younger, or the same age as, the oldest observation
    /// @param self The stored oracle array
    /// @param time The current block.timestamp
    /// @param target The timestamp at which the reserved observation should be for
    /// @param index The location of the most recently written observation within the oracle array
    /// @param cardinality The number of populated elements in the oracle array
    /// @return beforeOrAt The observation recorded before, or at, the target
    /// @return atOrAfter The observation recorded at, or after, the target
    function binarySearch(
        PackedObservation[32768] storage self,
        uint32 time,
        uint32 target,
        uint16 index,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        uint256 l = (index + 1) % cardinality; // oldest observation
        uint256 r = l + cardinality - 1; // newest observation
        uint256 i;
        while (true) {
            i = (l + r) / 2;

            beforeOrAt = get(self, uint16(i % cardinality));

            // we've landed on an uninitialized tick, keep searching higher (more recently)
            if (beforeOrAt.liquidityCumulative == 0) {
                l = i + 1;
                continue;
            }

            atOrAfter = get(self, uint16((i + 1) % cardinality));

            bool targetAtOrAfter = lte(time, beforeOrAt.blockTimestamp, target);

            // check if we've found the answer!
            if (targetAtOrAfter && lte(time, target, atOrAfter.blockTimestamp)) break;

            if (!targetAtOrAfter) r = i - 1;
            else l = i + 1;
        }
    }

    /// @notice Fetches the observations beforeOrAt and atOrAfter a given target, i.e. where [beforeOrAt, atOrAfter] is satisfied
    /// @dev There _must_ be at least 1 initialized observation.
    /// Used by observe() to contextualize a potential counterfactual observation as it would have occurred if a block
    /// were mined at the time of the desired observation
    /// @param self The stored oracle array
    /// @param time The current block.timestamp
    /// @param target The timestamp at which the reserved observation should be for
    /// @param tick The active tick at the time of the returned or simulated observation
    /// @param index The location of a given observation within the oracle array
    /// @param liquidity The total pair liquidity at the time of the call
    /// @param cardinality The number of populated elements in the oracle array
    /// @return beforeOrAt The observation which occurred at, or before, the given timestamp
    /// @return atOrAfter The observation which occurred at, or after, the given timestamp
    function getSurroundingObservations(
        PackedObservation[32768] storage self,
        uint32 time,
        uint32 target,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        // optimistically set before to the newest observation
        beforeOrAt = get(self, index);

        // if the target is chronologically at or after the newest observation, we can early return
        if (lte(time, beforeOrAt.blockTimestamp, target)) {
            if (beforeOrAt.blockTimestamp == target) {
                // if newest observation equals target, we're in the same block, so we can ignore atOrAfter
                return (beforeOrAt, atOrAfter);
            } else {
                // otherwise, we need to transform
                return (beforeOrAt, transform(beforeOrAt, target, tick, liquidityBit(liquidity)));
            }
        }

        // now, set before to the oldest observation
        beforeOrAt = get(self, (index + 1) % cardinality);
        if (beforeOrAt.liquidityCumulative == 0) beforeOrAt = get(self, 0);

        // ensure that the target is chronologically at or after the oldest observation
        require(lte(time, beforeOrAt.blockTimestamp, target), 'OLD');

        // if we've reached this point, we have to binary search
        return binarySearch(self, time, target, index, cardinality);
    }

    /// @notice Constructs a observation of a particular time, now or in the past.
    /// @dev Called from the pair contract. Contingent on having an observation at or before the desired observation.
    /// 0 may be passed as `secondsAgo' to return the present pair data.
    /// if called with a timestamp falling between two consecutive observations, returns a counterfactual observation
    /// as it would appear if a block were mined at the time of the call
    /// @param self The stored oracle array
    /// @param time The current block.timestamp
    /// @param secondsAgo The amount of time to look back, in seconds, at which point to return an observation
    /// @param tick The current tick
    /// @param index The location of a given observation within the oracle array
    /// @param liquidity The current in-range pair liquidity
    /// @param cardinality The number of populated elements in the oracle array
    /// @return tickCumulative The tick * time elapsed since the pair was first initialized, as of `secondsAgo`
    /// @return liquidityCumulative The (log base 2 of (liquidity + 1)) * time elapsed since the pair was first initialized, as of `secondsAgo`
    function observe(
        PackedObservation[32768] storage self,
        uint32 time,
        uint32 secondsAgo,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56 tickCumulative, uint40 liquidityCumulative) {
        require(cardinality > 0, 'I');

        if (secondsAgo == 0) {
            Observation memory last = get(self, index);
            if (last.blockTimestamp != time) last = transform(last, time, tick, liquidityBit(liquidity));
            return (last.tickCumulative, last.liquidityCumulative >> 1);
        }

        uint32 target = time - secondsAgo;

        (Observation memory beforeOrAt, Observation memory atOrAfter) =
            getSurroundingObservations(self, time, target, tick, index, liquidity, cardinality);

        Oracle.Observation memory at;
        if (target == beforeOrAt.blockTimestamp) {
            // we're at the left boundary
            at = beforeOrAt;
        } else if (target == atOrAfter.blockTimestamp) {
            // we're at the right boundary
            at = atOrAfter;
        } else {
            // we're in the middle
            uint32 delta = atOrAfter.blockTimestamp - beforeOrAt.blockTimestamp;
            int24 tickDerived = int24((atOrAfter.tickCumulative - beforeOrAt.tickCumulative) / delta);
            uint8 liquidityBitDerived =
                uint8(((atOrAfter.liquidityCumulative >> 1) - (beforeOrAt.liquidityCumulative >> 1)) / delta);
            at = transform(beforeOrAt, target, tickDerived, liquidityBitDerived);
        }

        return (at.tickCumulative, at.liquidityCumulative >> 1);
    }
}
