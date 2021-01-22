// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import './SqrtTickMath.sol';
import './SafeCast.sol';
import './LiquidityMath.sol';
import './SignedSafeMath.sol';

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
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
    }

    function tickSpacingToParameters(int24 tickSpacing)
        internal
        pure
        returns (
            int24 minTick,
            int24 maxTick,
            uint128 maxLiquidityPerTick
        )
    {
        minTick = (SqrtTickMath.MIN_TICK / tickSpacing) * tickSpacing;
        maxTick = (SqrtTickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        maxLiquidityPerTick = type(uint128).max / numTicks;
    }

    function _getFeeGrowthBelow(
        int24 tick,
        int24 tickCurrent,
        Info storage info,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) private view returns (uint256 feeGrowthBelow0X128, uint256 feeGrowthBelow1X128) {
        // tick is above the current tick, meaning growth outside represents growth above, not below
        if (tick > tickCurrent) {
            feeGrowthBelow0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 = info.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = info.feeGrowthOutside1X128;
        }
    }

    function _getFeeGrowthAbove(
        int24 tick,
        int24 tickCurrent,
        Info storage info,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) private view returns (uint256 feeGrowthAbove0X128, uint256 feeGrowthAbove1X128) {
        // tick is above current tick, meaning growth outside represents growth above
        if (tick > tickCurrent) {
            feeGrowthAbove0X128 = info.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = info.feeGrowthOutside1X128;
        } else {
            feeGrowthAbove0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
        }
    }

    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        (uint256 feeGrowthBelow0X128, uint256 feeGrowthBelow1X128) =
            _getFeeGrowthBelow(tickLower, tickCurrent, self[tickLower], feeGrowthGlobal0X128, feeGrowthGlobal1X128);
        (uint256 feeGrowthAbove0X128, uint256 feeGrowthAbove1X128) =
            _getFeeGrowthAbove(tickUpper, tickCurrent, self[tickUpper], feeGrowthGlobal0X128, feeGrowthGlobal1X128);
        feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128;
        feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128;
    }

    // updates a tick and returns true iff the tick was flipped from initialized to uninitialized or vice versa
    function update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        int24 tickCurrent,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint32 blockTimestamp,
        bool upper,
        uint128 maxLiquidity
    ) internal returns (bool flipped) {
        Tick.Info storage info = self[tick];

        if (liquidityDelta != 0) {
            uint128 liquidityGrossBefore = info.liquidityGross;
            uint128 liquidityGrossAfter = LiquidityMath.addDelta(liquidityGrossBefore, liquidityDelta);

            require(liquidityGrossAfter <= maxLiquidity, 'LO');

            flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0);

            if (liquidityGrossBefore == 0) {
                // by convention, we assume that all growth before a tick was initialized happened _below_ the tick
                if (tick <= tickCurrent) {
                    info.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                    info.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
                    info.secondsOutside = blockTimestamp;
                }
            }

            info.liquidityGross = liquidityGrossAfter;

            // when the lower (upper) tick is crossed left to right (right to left), liquidity must be added (removed)
            info.liquidityDelta = upper
                ? SafeCast.toInt128(SignedSafeMath.sub(info.liquidityDelta, liquidityDelta))
                : SafeCast.toInt128(SignedSafeMath.add(info.liquidityDelta, liquidityDelta));
        }
    }

    function clear(mapping(int24 => Tick.Info) storage self, int24 tick) internal {
        delete self[tick];
    }

    function cross(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        uint32 blockTimestamp
    ) internal returns (int128 liquidityDelta) {
        Tick.Info storage info = self[tick];
        info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128;
        info.secondsOutside = blockTimestamp - info.secondsOutside; // overflow is desired
        liquidityDelta = info.liquidityDelta;
    }
}
