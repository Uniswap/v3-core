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
        uint256 feeGrowthOutside0;
        uint256 feeGrowthOutside1;
    }

    function _getFeeGrowthBelow(
        int24 tick,
        int24 tickCurrent,
        Info storage tickInfo,
        uint256 feeGrowthGlobal0,
        uint256 feeGrowthGlobal1
    ) private view returns (uint256 feeGrowthBelow0, uint256 feeGrowthBelow1) {
        // tick is above the current tick, meaning growth outside represents growth above, not below
        if (tick > tickCurrent) {
            feeGrowthBelow0 = feeGrowthGlobal0 - tickInfo.feeGrowthOutside0;
            feeGrowthBelow1 = feeGrowthGlobal1 - tickInfo.feeGrowthOutside1;
        } else {
            feeGrowthBelow0 = tickInfo.feeGrowthOutside0;
            feeGrowthBelow1 = tickInfo.feeGrowthOutside1;
        }
    }

    function _getFeeGrowthAbove(
        int24 tick,
        int24 tickCurrent,
        Info storage tickInfo,
        uint256 feeGrowthGlobal0,
        uint256 feeGrowthGlobal1
    ) private view returns (uint256 feeGrowthAbove0, uint256 feeGrowthAbove1) {
        // tick is above current tick, meaning growth outside represents growth above
        if (tick > tickCurrent) {
            feeGrowthAbove0 = tickInfo.feeGrowthOutside0;
            feeGrowthAbove1 = tickInfo.feeGrowthOutside1;
        } else {
            feeGrowthAbove0 = feeGrowthGlobal0 - tickInfo.feeGrowthOutside0;
            feeGrowthAbove1 = feeGrowthGlobal1 - tickInfo.feeGrowthOutside1;
        }
    }

    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0,
        uint256 feeGrowthGlobal1
    ) internal view returns (uint256 feeGrowthInside0, uint256 feeGrowthInside1) {
        (uint256 feeGrowthBelow0, uint256 feeGrowthBelow1) =
            _getFeeGrowthBelow(tickLower, tickCurrent, self[tickLower], feeGrowthGlobal0, feeGrowthGlobal1);
        (uint256 feeGrowthAbove0, uint256 feeGrowthAbove1) =
            _getFeeGrowthAbove(tickUpper, tickCurrent, self[tickUpper], feeGrowthGlobal0, feeGrowthGlobal1);
        feeGrowthInside0 = feeGrowthGlobal0 - feeGrowthBelow0 - feeGrowthAbove0;
        feeGrowthInside1 = feeGrowthGlobal1 - feeGrowthBelow1 - feeGrowthAbove1;
    }
}
