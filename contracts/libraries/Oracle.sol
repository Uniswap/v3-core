// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

library Oracle {
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

    function writeObservationIfNecessary(
        Observation[CARDINALITY] storage self,
        uint16 index,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity
    ) internal returns (uint16 indexNext) {
        Observation memory last = self[index];

        if (last.blockTimestamp != blockTimestamp) {
            indexNext = (index + 1) % CARDINALITY;
            uint32 timestampDelta = blockTimestamp - last.blockTimestamp;
            self[indexNext] = Observation({
                blockTimestamp: blockTimestamp,
                tickCumulative: last.tickCumulative + int56(tick) * timestampDelta,
                liquidityCumulative: last.liquidityCumulative + uint160(liquidity) * timestampDelta,
                initialized: true
            });
        } else {
            indexNext = index;
        }
    }

    // this function only works if very specific conditions are true, which must be enforced elsewhere
    // note that even though we're not modifying self, it must be passed by ref to save gas
    function scry(
        Observation[CARDINALITY] storage self,
        uint32 target,
        uint16 index
    ) internal view returns (int24 tickThen, uint128 liquidityThen) {
        Observation memory before;
        Observation memory atOrAfter;

        uint16 l = (index + 1) % CARDINALITY;
        uint16 r = l + CARDINALITY - 1;
        uint16 i;
        while (true) {
            i = (l + r) / 2;

            atOrAfter = self[i % CARDINALITY];

            // we've landed on an uninitialized tick, keep searching higher (more recently)
            if (atOrAfter.initialized == false) {
                l = i + 1;
                continue;
            }

            before = self[((i % CARDINALITY) == 0 ? CARDINALITY : i % CARDINALITY) - 1];

            // we've found the answer!
            if (
                (before.blockTimestamp < target && target <= atOrAfter.blockTimestamp) ||
                (before.blockTimestamp > atOrAfter.blockTimestamp &&
                    (before.blockTimestamp < target || target <= atOrAfter.blockTimestamp))
            ) break;

            uint256 mostRecent = self[r % CARDINALITY].blockTimestamp;
            uint256 atOrAfterAdjusted = atOrAfter.blockTimestamp;
            uint256 targetAdjusted = target;
            if (atOrAfterAdjusted > mostRecent || targetAdjusted > mostRecent) {
                if (atOrAfterAdjusted <= mostRecent) atOrAfterAdjusted += 2**32;
                if (targetAdjusted <= mostRecent) targetAdjusted += 2**32;
            }

            // keep searching higher (more recently) if necessary
            if (atOrAfterAdjusted < targetAdjusted) {
                l = i + 1;
                continue;
            }

            // otherwise, the only remaining option is to keep searching lower (less recently)
            r = i - 1;
        }

        uint32 delta = atOrAfter.blockTimestamp - before.blockTimestamp;
        return (
            int24((atOrAfter.tickCumulative - before.tickCumulative) / delta),
            uint128((atOrAfter.liquidityCumulative - before.liquidityCumulative) / delta)
        );
    }
}
