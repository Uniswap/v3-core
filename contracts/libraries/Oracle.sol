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

        if (last.blockTimestamp == blockTimestamp) return index;

        indexNext = (index + 1) % CARDINALITY;
        uint32 timestampDelta = blockTimestamp - last.blockTimestamp;
        self[indexNext] = Observation({
            blockTimestamp: blockTimestamp,
            tickCumulative: last.tickCumulative + int56(tick) * timestampDelta,
            liquidityCumulative: last.liquidityCumulative + uint160(liquidity) * timestampDelta,
            initialized: true
        });
    }

    // this function only works if very specific conditions are true, which must be enforced elsewhere
    // note that even though we're not modifying self, it must be passed by ref to save gas
    function scry(
        Observation[CARDINALITY] storage self,
        uint32 target,
        uint16 index
    ) internal view returns (uint16 i) {
        Observation memory atOrAfter;
        uint256 beforeBlockTimestamp;

        uint16 l = (index + 1) % CARDINALITY;
        uint16 r = l + CARDINALITY - 1;
        while (true) {
            i = (l + r) / 2;

            atOrAfter = self[i % CARDINALITY];

            // we've landed on an uninitialized tick, keep searching higher (more recently)
            if (!atOrAfter.initialized) {
                l = i + 1;
                continue;
            }

            beforeBlockTimestamp = (i == CARDINALITY ? self[CARDINALITY - 1] : self[(i % CARDINALITY) - 1])
                .blockTimestamp;

            // we've found the answer!
            if (
                (beforeBlockTimestamp < target && target <= atOrAfter.blockTimestamp) ||
                (beforeBlockTimestamp > atOrAfter.blockTimestamp &&
                    (beforeBlockTimestamp < target || target <= atOrAfter.blockTimestamp))
            ) break;

            uint256 mostRecent = self[r % CARDINALITY].blockTimestamp;
            uint256 atOrAfterAdjusted = atOrAfter.blockTimestamp;
            uint256 targetAdjusted = target;
            if (atOrAfterAdjusted > mostRecent || targetAdjusted > mostRecent) {
                if (atOrAfterAdjusted <= mostRecent) atOrAfterAdjusted += 2**32;
                if (targetAdjusted <= mostRecent) targetAdjusted += 2**32;
            }

            if (atOrAfterAdjusted < targetAdjusted) l = i + 1;
            else r = i - 1;
        }

        i %= CARDINALITY;
    }
}
