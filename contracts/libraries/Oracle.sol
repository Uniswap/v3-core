// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

library Oracle {
    uint16 private constant CARDINALITY = 1024;

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

    function scry(
        Observation[CARDINALITY] memory self,
        uint32 target,
        uint32 current,
        uint16 index,
        int24 tickCurrent,
        uint128 liquidityCurrent
    )
        internal
        pure
        returns (int24 tick, uint128 liquidity)
    {
        Observation memory before;
        Observation memory atOrAfter;

        // to start, set before to the oldest known observation (while ensuring it exists)
        before = self[(index + 1) % CARDINALITY];
        if (before.initialized == false) {
            before = self[0];
            require(before.initialized, 'UI');
        }

        // now, ensure that the target is greater than the oldest observation (accounting for wrapping)
        require(before.blockTimestamp < target || (before.blockTimestamp > current && target <= current), 'OLD');

        // check if the target is after the youngest observation, and if so return the current values
        atOrAfter = self[index];
        if (atOrAfter.blockTimestamp < target || (atOrAfter.blockTimestamp > current && target <= current))
            return (tickCurrent, liquidityCurrent);

        // once here, we can be confident that the answer is in the array, time for binary search!
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
            if (atOrAfter.blockTimestamp < target || self[l % CARDINALITY].blockTimestamp > target) {
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
