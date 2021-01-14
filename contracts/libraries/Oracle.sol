// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

library Oracle {
    // the number of observations, at most one per block, stored in an array that is cycled over
    uint16 internal constant CARDINALITY = 1024;

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
    ) internal pure returns (Observation memory) {
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
        Observation[CARDINALITY] storage self,
        uint16 index,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity
    ) internal returns (uint16 indexNext) {
        Observation memory last = self[index];

        // early return if we've already written an observation this block
        if (last.blockTimestamp == blockTimestamp) return index;

        indexNext = (index + 1) % CARDINALITY;
        self[indexNext] = transform(last, blockTimestamp, tick, liquidity);
    }

    // fetches the observations before and atOrAfter a target, i.e. where this range is satisfied: (before, atOrAfter]
    // the answer _must_ be contained in the array
    // note that even though we're not modifying self, it must be passed by ref to save gas
    function binarySearch(
        Observation[CARDINALITY] storage self,
        uint32 target,
        uint16 index
    ) internal view returns (Oracle.Observation memory before, Oracle.Observation memory atOrAfter) {
        uint16 l = (index + 1) % CARDINALITY;
        uint16 r = l + CARDINALITY - 1;
        uint16 i;
        while (true) {
            i = (l + r) / 2;

            atOrAfter = self[i % CARDINALITY];

            // we've landed on an uninitialized tick, keep searching higher (more recently)
            if (!atOrAfter.initialized) {
                l = i + 1;
                continue;
            }

            before = i == CARDINALITY ? self[CARDINALITY - 1] : self[(i % CARDINALITY) - 1];

            // check if we've found the answer!
            if (
                (before.blockTimestamp < target && target <= atOrAfter.blockTimestamp) ||
                (before.blockTimestamp > atOrAfter.blockTimestamp &&
                    (before.blockTimestamp < target || target <= atOrAfter.blockTimestamp))
            ) break;

            // adjust for overflow
            uint256 targetAdjusted = target;
            uint256 atOrAfterAdjusted = atOrAfter.blockTimestamp;
            uint256 newestAdjusted = self[r % CARDINALITY].blockTimestamp;
            if (targetAdjusted > newestAdjusted || atOrAfterAdjusted > newestAdjusted) {
                if (targetAdjusted <= newestAdjusted) targetAdjusted += 2**32;
                if (atOrAfterAdjusted <= newestAdjusted) atOrAfterAdjusted += 2**32;
            }

            if (atOrAfterAdjusted < targetAdjusted) l = i + 1;
            else r = i - 1;
        }
    }
}
