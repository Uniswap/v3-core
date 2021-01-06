// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import '../libraries/Tick.sol';

contract TickTest {
    using Tick for mapping(int24 => Tick.Info);

    mapping(int24 => Tick.Info) public ticks;

    function tickSpacingToParameters(int24 tickSpacing)
        external
        pure
        returns (
            int24 minTick,
            int24 maxTick,
            uint128 maxLiquidityPerTick
        )
    {
        return Tick.tickSpacingToParameters(tickSpacing);
    }

    function setTick(int24 tick, Tick.Info memory info) external {
        ticks[tick] = info;
    }

    function getFeeGrowthInside(
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) external view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        return ticks.getFeeGrowthInside(tickLower, tickUpper, tickCurrent, feeGrowthGlobal0X128, feeGrowthGlobal1X128);
    }
}
