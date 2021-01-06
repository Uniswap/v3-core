// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/Tick.sol';

contract TickTest {
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
}
