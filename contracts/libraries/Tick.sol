// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import './FixedPoint128.sol';

library Tick {
    // info stored for each initialized individual tick
    struct Info {
        // the total position liquidity that references this tick
        uint128 liquidityGross;
        // amount of liquidity added (subtracted) when tick is crossed from left to right (right to left),
        // i.e. as the price goes up (down), for each fee vote
        int128 liquidityDelta;
        // seconds spent on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        uint32 secondsOutside;
        // fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
        // only has relative meaning, not absolute — the value depends on when the tick is initialized
        FixedPoint128.uq128x128 feeGrowthOutside0;
        FixedPoint128.uq128x128 feeGrowthOutside1;
    }

    function _getFeeGrowthBelow(
        int24 tick,
        int24 tickCurrent,
        Info storage tickInfo,
        FixedPoint128.uq128x128 memory feeGrowthGlobal0,
        FixedPoint128.uq128x128 memory feeGrowthGlobal1
    )
        private
        view
        returns (FixedPoint128.uq128x128 memory feeGrowthBelow0, FixedPoint128.uq128x128 memory feeGrowthBelow1)
    {
        // tick is above the current tick, meaning growth outside represents growth above, not below
        if (tick > tickCurrent) {
            feeGrowthBelow0 = FixedPoint128.uq128x128(feeGrowthGlobal0._x - tickInfo.feeGrowthOutside0._x);
            feeGrowthBelow1 = FixedPoint128.uq128x128(feeGrowthGlobal1._x - tickInfo.feeGrowthOutside1._x);
        } else {
            feeGrowthBelow0 = tickInfo.feeGrowthOutside0;
            feeGrowthBelow1 = tickInfo.feeGrowthOutside1;
        }
    }

    function _getFeeGrowthAbove(
        int24 tick,
        int24 tickCurrent,
        Info storage tickInfo,
        FixedPoint128.uq128x128 memory feeGrowthGlobal0,
        FixedPoint128.uq128x128 memory feeGrowthGlobal1
    )
        private
        view
        returns (FixedPoint128.uq128x128 memory feeGrowthAbove0, FixedPoint128.uq128x128 memory feeGrowthAbove1)
    {
        // tick is above current tick, meaning growth outside represents growth above
        if (tick > tickCurrent) {
            feeGrowthAbove0 = tickInfo.feeGrowthOutside0;
            feeGrowthAbove1 = tickInfo.feeGrowthOutside1;
        } else {
            feeGrowthAbove0 = FixedPoint128.uq128x128(feeGrowthGlobal0._x - tickInfo.feeGrowthOutside0._x);
            feeGrowthAbove1 = FixedPoint128.uq128x128(feeGrowthGlobal1._x - tickInfo.feeGrowthOutside1._x);
        }
    }

    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        FixedPoint128.uq128x128 memory feeGrowthGlobal0,
        FixedPoint128.uq128x128 memory feeGrowthGlobal1
    )
        internal
        view
        returns (FixedPoint128.uq128x128 memory feeGrowthInside0, FixedPoint128.uq128x128 memory feeGrowthInside1)
    {
        (FixedPoint128.uq128x128 memory feeGrowthBelow0, FixedPoint128.uq128x128 memory feeGrowthBelow1) =
            _getFeeGrowthBelow(tickLower, tickCurrent, self[tickLower], feeGrowthGlobal0, feeGrowthGlobal1);
        (FixedPoint128.uq128x128 memory feeGrowthAbove0, FixedPoint128.uq128x128 memory feeGrowthAbove1) =
            _getFeeGrowthAbove(tickUpper, tickCurrent, self[tickUpper], feeGrowthGlobal0, feeGrowthGlobal1);
        feeGrowthInside0 = FixedPoint128.uq128x128(feeGrowthGlobal0._x - feeGrowthBelow0._x - feeGrowthAbove0._x);
        feeGrowthInside1 = FixedPoint128.uq128x128(feeGrowthGlobal1._x - feeGrowthBelow1._x - feeGrowthAbove1._x);
    }
}
