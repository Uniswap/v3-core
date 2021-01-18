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

    // transforms an oracle observation in a subsequent observation, given the passage of time and current values
    // blockTimestamp _must_ be at or after last.blockTimestamp (accounting for overflow)
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
        if (index == (cardinality - 1) && cardinalityTarget > cardinality) {
            cardinalityNext = cardinalityTarget;
            // TODO we want to emit this
            // emit ObservationCardinalityIncreased(cardinality, cardinalityTarget);
        } else {
            cardinalityNext = cardinality;
        }

        indexNext = (index + 1) % cardinalityNext;
        self[indexNext] = transform(last, blockTimestamp, tick, liquidity);
    }

    // fetches the observations before and atOrAfter a target, i.e. where this range is satisfied: (before, atOrAfter]
    // the answer _must_ be contained in the array
    // note that even though we're not modifying self, it must be passed by ref to save gas
    function binarySearch(
        Observation[65535] storage self,
        uint32 target,
        uint16 index,
        uint16 cardinality
    ) private view returns (Observation memory before, Observation memory atOrAfter) {
        uint16 l = (index + 1) % cardinality;
        uint16 r = l + cardinality - 1;
        uint16 i;
        while (true) {
            i = (l + r) / 2;

            atOrAfter = self[i % cardinality];

            // we've landed on an uninitialized tick, keep searching higher (more recently)
            if (!atOrAfter.initialized) {
                l = i + 1;
                continue;
            }

            before = i == cardinality ? self[cardinality - 1] : self[(i % cardinality) - 1];

            // check if we've found the answer!
            if (
                (before.blockTimestamp < target && target <= atOrAfter.blockTimestamp) ||
                (before.blockTimestamp > atOrAfter.blockTimestamp &&
                    (before.blockTimestamp < target || target <= atOrAfter.blockTimestamp))
            ) break;

            // adjust for overflow
            uint256 targetAdjusted = target;
            uint256 atOrAfterAdjusted = atOrAfter.blockTimestamp;
            uint256 newestAdjusted = self[r % cardinality].blockTimestamp;
            if (targetAdjusted > newestAdjusted || atOrAfterAdjusted > newestAdjusted) {
                if (targetAdjusted <= newestAdjusted) targetAdjusted += 2**32;
                if (atOrAfterAdjusted <= newestAdjusted) atOrAfterAdjusted += 2**32;
            }

            if (atOrAfterAdjusted < targetAdjusted) l = i + 1;
            else r = i - 1;
        }
    }

    // fetches the observations before and atOrAfter a target, i.e. where this range is satisfied: (before, atOrAfter]
    function getSurroundingObservations(
        Observation[65535] storage self,
        uint32 current,
        uint32 target,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) private view returns (Observation memory before, Observation memory) {
        // first, set before to the oldest observation, and make sure it's initialized
        before = self[(index + 1) % cardinality];
        if (!before.initialized) {
            before = self[0];
            require(before.initialized, 'UI');
        }

        // ensure that the target is greater than the oldest observation (accounting for wrapping)
        require(before.blockTimestamp < target || (before.blockTimestamp > current && target <= current), 'OLD');

        // now, optimistically set before to the newest observation
        before = self[index];

        // before proceeding, short-circuit if the target equals the newest observation, meaning we're in the same block
        // but an interaction updated the oracle before this tx, so before is actually atOrAfter
        if (target == before.blockTimestamp) return (index == 0 ? self[cardinality - 1] : self[index - 1], before);

        // adjust for overflow
        uint256 beforeAdjusted = before.blockTimestamp;
        uint256 targetAdjusted = target;
        if (beforeAdjusted > current && targetAdjusted <= current) targetAdjusted += 2**32;
        if (targetAdjusted > current) beforeAdjusted += 2**32;

        // once here, check if we're right and return a counterfactual observation for atOrAfter
        if (beforeAdjusted < targetAdjusted) return (before, transform(before, current, tick, liquidity));

        // we're wrong, so perform binary search
        return binarySearch(self, target, index, cardinality);
    }

    // constructs a counterfactual observation as of a particular time in the past, as long as we have observations before then
    function scry(
        Observation[65535] storage self,
        uint32 current,
        uint32 secondsAgo,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56 tickCumulative, uint160 liquidityCumulative) {
        uint32 target = current - secondsAgo;

        (Observation memory before, Observation memory atOrAfter) =
            getSurroundingObservations(self, current, target, tick, index, liquidity, cardinality);

        Oracle.Observation memory at;
        if (target == atOrAfter.blockTimestamp) {
            // if we're at the right boundary, make it so
            at = atOrAfter;
        } else {
            // else, adjust counterfactually
            uint32 delta = atOrAfter.blockTimestamp - before.blockTimestamp;
            int24 tickDerived = int24((atOrAfter.tickCumulative - before.tickCumulative) / delta);
            uint128 liquidityDerived = uint128((atOrAfter.liquidityCumulative - before.liquidityCumulative) / delta);
            at = transform(before, target, tickDerived, liquidityDerived);
        }

        return (at.tickCumulative, at.liquidityCumulative);
    }
}
