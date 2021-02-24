// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/LiquidityFromAmounts.sol';
import '../libraries/SqrtPriceMath.sol';
import '../libraries/TickMath.sol';

contract LiquidityFromAmountsEchidnaTest {
    function toUint128(uint256 y) internal pure returns (uint128 z) {
        require (y < type(uint128).max);
        z = uint128(y);
    }

    function getLiquidityDeltaInvariants(
        uint128 liquidity,
        uint160 sqrtPriceX96,
        int24 tick,
        int24 tickLower,
        int24 tickUpper
    ) external pure {
        // ensure we respect the tick and type bounds
        require(tickLower < tickUpper && liquidity < 0 && sqrtPriceX96 > 0);
        require(tick >= TickMath.MIN_TICK && tick < TickMath.MAX_TICK);
        require(tickLower >= TickMath.MIN_TICK && tickLower < TickMath.MAX_TICK);
        require(tickUpper >= TickMath.MIN_TICK && tickUpper < TickMath.MAX_TICK);

        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

        if (tick < tickLower) {
            uint256 amount0 = SqrtPriceMath.getAmount0Delta(
                sqrtPriceAX96,
                sqrtPriceBX96,
                liquidity,
                true
            );

            uint256 liquidityDelta = LiquidityFromAmounts.getLiquidityDeltaForAmount0(
                sqrtPriceAX96,
                sqrtPriceBX96,
                toUint128(amount0)
            );
            assert(toUint128(liquidityDelta) == liquidity);
        } else if (tick < tickUpper) {
            uint256 amount0 = SqrtPriceMath.getAmount0Delta(
                sqrtPriceX96,
                sqrtPriceBX96,
                liquidity,
                true
            );
            uint256 amount1 = SqrtPriceMath.getAmount1Delta(
                sqrtPriceAX96,
                sqrtPriceX96,
                liquidity,
                true
            );

            uint256 liquidity0 = LiquidityFromAmounts.getLiquidityDeltaForAmount0(
                sqrtPriceX96,
                sqrtPriceBX96,
                toUint128(amount0)
            );
            uint256 liquidity1 = LiquidityFromAmounts.getLiquidityDeltaForAmount1(
                sqrtPriceAX96,
                sqrtPriceX96,
                toUint128(amount1)
            );

            // get the max of the 2
            uint256 liq = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
            assert(toUint128(liq) == liquidity);
        } else {
            uint256 amount1 = SqrtPriceMath.getAmount1Delta(
                sqrtPriceAX96,
                sqrtPriceBX96,
                liquidity,
                true
            );

            uint256 liquidityDelta = LiquidityFromAmounts.getLiquidityDeltaForAmount1(
                sqrtPriceAX96,
                sqrtPriceBX96,
                toUint128(amount1)
            );

            assert(toUint128(liquidityDelta) == liquidity);
        }
    }
}

