// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '../libraries/FixedPoint128.sol';
import '../libraries/TickMath.sol';
import '../libraries/SwapMath.sol';

contract SwapMathEchidnaTest {
    function requirePriceWithinBounds(uint128 price) private pure {
        require(price < TickMath.getRatioAtTick(TickMath.MAX_TICK / 2));
        require(price >= TickMath.getRatioAtTick(TickMath.MIN_TICK / 2));
    }

    function checkComputeSwapStepInvariants(
        uint128 sqrtPriceRaw,
        uint128 sqrtPriceTargetRaw,
        uint128 liquidity,
        uint256 amountInMax,
        uint24 feePips
    ) external pure {
        requirePriceWithinBounds(sqrtPriceRaw);
        requirePriceWithinBounds(sqrtPriceTargetRaw);
        require(feePips < 1e6);

        bool zeroForOne = sqrtPriceRaw >= sqrtPriceTargetRaw;

        require(amountInMax > 0);

        (
            FixedPoint64.uq64x64 memory sqrtQ,
            uint256 amountIn, /*uint256 amountOut*/
            ,
            uint256 feeAmount
        ) = SwapMath.computeSwapStep(
            FixedPoint64.uq64x64(sqrtPriceRaw),
            FixedPoint64.uq64x64(sqrtPriceTargetRaw),
            liquidity,
            amountInMax,
            feePips,
            zeroForOne
        );

        if (zeroForOne) {
            assert(sqrtQ._x <= sqrtPriceRaw);
            assert(sqrtQ._x >= sqrtPriceTargetRaw);
        } else {
            assert(sqrtQ._x >= sqrtPriceRaw);
            assert(sqrtQ._x <= sqrtPriceTargetRaw);
        }

        assert(amountIn + feeAmount <= amountInMax);
    }
}
