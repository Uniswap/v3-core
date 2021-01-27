// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

library Oracle {
    struct Observation {
        // the block timestamp of the observation
        uint32 blockTimestamp;
        // the tick accumulator, i.e. tick * time elapsed since the pair was first initialized
        int56 tickCumulative;
        // the liquidity accumulator, i.e. liquidity * time elapsed since the pair was first initialized
        uint160 liquidityCumulative;
        // whether or not the observation is initialized
        bool initialized;
    }

    // transforms an oracle observation into a subsequent observation, given the passage of time and current values
    // blockTimestamp _must_ be chronologically equal to or greater than last.blockTimestamp
    // safe for 0 or 1 overflows
    function transform(
        Observation memory last,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity
    ) private pure returns (Observation memory) {
        uint32 delta = blockTimestamp - last.blockTimestamp;
        return
            Observation({
                blockTimestamp: blockTimestamp,
                tickCumulative: last.tickCumulative + int56(tick) * delta,
                liquidityCumulative: last.liquidityCumulative + uint160(liquidity) * delta,
                initialized: true
            });
    }

    // initialize the oracle array by writing the first slot. called once for the lifecycle of the observations array.
    function initialize(Observation[65535] storage self, uint32 time)
        internal
        returns (uint16 cardinality, uint16 target)
    {
        self[0] = Observation({blockTimestamp: time, tickCumulative: 0, liquidityCumulative: 0, initialized: true});
        return (1, 1);
    }

    // writes an oracle observation to the array, at most once per block
    // indices cycle, and must be kept track of in the parent contract
    function write(
        Observation[65535] storage self,
        uint16 index,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity,
        uint16 cardinality,
        uint16 cardinalityTarget
    ) internal returns (uint16 indexNext, uint16 cardinalityNext) {
        Observation memory last = self[index];

        // early return if we've already written an observation this block
        if (last.blockTimestamp == blockTimestamp) return (index, cardinality);

        // if the conditions are right, we can bump the cardinality
        if (cardinalityTarget > cardinality && index == (cardinality - 1)) {
            cardinalityNext = cardinalityTarget;
        } else {
            cardinalityNext = cardinality;
        }

        indexNext = (index + 1) % cardinalityNext;
        self[indexNext] = transform(last, blockTimestamp, tick, liquidity);
    }

    // grow the observations array. observations array length is stored in cardinality and target. cardinality cannot be
    // changed unless the index is currently the last element of the array, to avoid reordering in all other cases.
    // the cardinality is either immediately changed if the above is true, or changed on the next write when the write
    // fills the last index lt current cardinality.
    function grow(
        Observation[65535] storage self,
        uint16 index,
        uint16 cardinalityOld,
        uint16 targetOld,
        uint16 targetNew
    ) internal returns (uint16 cardinality, uint16 target) {
        // no op if old target is new target
        if (targetNew <= targetOld) return (cardinalityOld, targetOld);
        // store in each slot to prevent fresh SSTOREs in swaps
        // this data will not be used because the initialized boolean is still false
        for (uint16 i = targetOld; i < targetNew; i++) self[i].blockTimestamp = 1;
        // if the index is already at the last element of the array, immediately grow the cardinality
        cardinality = index == cardinalityOld - 1 ? targetNew : cardinalityOld;
        target = targetNew;
    }

    // comparator for 32-bit timestamps
    // safe for 0 or 1 overflows
    // a and b _must_ be chronologically before or equal to time
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

    // fetches the observations beforeOrAt and atOrAfter a target, i.e. where [beforeOrAt, atOrAfter] is satisfied
    // the answer _must_ be contained in the array
    function binarySearch(
        Observation[65535] storage self,
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

            beforeOrAt = self[i % cardinality];

            // we've landed on an uninitialized tick, keep searching higher (more recently)
            if (!beforeOrAt.initialized) {
                l = i + 1;
                continue;
            }

            atOrAfter = self[(i + 1) % cardinality];

            bool targetAtOrAfter = lte(time, beforeOrAt.blockTimestamp, target);

            // check if we've found the answer!
            if (targetAtOrAfter && lte(time, target, atOrAfter.blockTimestamp)) break;

            if (!targetAtOrAfter) r = i - 1;
            else l = i + 1;
        }
    }

    // fetches the observations before and atOrAfter a target, i.e. where this range is satisfied: (before, atOrAfter]
    // there _must_ be at least 1 initialized observation
    function getSurroundingObservations(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        // optimistically set before to the newest observation
        beforeOrAt = self[index];
        assert(beforeOrAt.initialized);

        // if the target is chronologically at or after the newest observation, we can early return
        if (lte(time, beforeOrAt.blockTimestamp, target)) {
            if (beforeOrAt.blockTimestamp == target) {
                // if newest observation equals target, we're in the same block, so we can ignore atOrAfter
                return (beforeOrAt, atOrAfter);
            } else {
                // otherwise, we need to transform
                return (beforeOrAt, transform(beforeOrAt, target, tick, liquidity));
            }
        }

        // now, set before to the oldest observation
        beforeOrAt = self[(index + 1) % cardinality];
        if (!beforeOrAt.initialized) beforeOrAt = self[0];

        // ensure that the target is chronologically at or after the oldest observation
        require(lte(time, beforeOrAt.blockTimestamp, target), 'OLD');

        // if we've reached this point, we have to binary search
        return binarySearch(self, time, target, index, cardinality);
    }

    // constructs a counterfactual observation as of a particular time in the past (or now) as long as we have
    // an observation at or before then
    function scry(
        Observation[65535] storage self,
        uint32 time,
        uint32 secondsAgo,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56 tickCumulative, uint160 liquidityCumulative) {
        require(cardinality > 0, 'I');
        if (secondsAgo == 0) {
            Observation memory last = self[index];
            if (last.blockTimestamp != time) last = transform(last, time, tick, liquidity);
            return (last.tickCumulative, last.liquidityCumulative);
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
            uint128 liquidityDerived =
                uint128((atOrAfter.liquidityCumulative - beforeOrAt.liquidityCumulative) / delta);
            at = transform(beforeOrAt, target, tickDerived, liquidityDerived);
        }

        return (at.tickCumulative, at.liquidityCumulative);
    }
}
