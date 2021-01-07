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
        // TODO storage -> memory here and below?
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
    function scry(Observation[CARDINALITY] storage self, uint32 target, uint16 index, uint32 current)
        internal
        view
        returns (int24 tick, uint128 liquidity)
    {
        Observation memory before;
        Observation memory atOrAfter;

        uint16 l = (index + 1) % CARDINALITY;
        uint16 r = l + CARDINALITY - 1;
        uint16 i;
        while (true) {
            i = (l + r) / 2;

            atOrAfter = self[i % CARDINALITY];

            // we've landed on an uninitialized tick, keeping searching lower
            if (atOrAfter.initialized == false) {
                r = i - 1;
                continue;
            }

            before = self[((i % CARDINALITY) == 0 ? CARDINALITY: i % CARDINALITY) - 1];

            // we've found the answer!
            if ((
                before.blockTimestamp < target && target <= atOrAfter.blockTimestamp
            ) || (
                before.blockTimestamp > atOrAfter.blockTimestamp && (
                    before.blockTimestamp < target || target <= atOrAfter.blockTimestamp
                )
            )) break;

            // we need to get more recent, keep searching higher
            if (atOrAfter.blockTimestamp < target || (atOrAfter.blockTimestamp > current && target <= current)) {
                l = i + 1;
                continue;
            }

            // the only remaining option is that we need to get less recent, keep searching lower
            r = i - 1;
        }

        uint32 delta = atOrAfter.blockTimestamp - before.blockTimestamp;
        return (
            int24((atOrAfter.tickCumulative - before.tickCumulative) / delta),
            uint128((atOrAfter.liquidityCumulative - before.liquidityCumulative) / delta)
        );
    }
}
