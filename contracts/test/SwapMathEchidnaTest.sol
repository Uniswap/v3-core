// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/FixedPoint128.sol';
import '../libraries/SwapMath.sol';

contract SwapMathEchidnaTest {
    function checkComputeSwapStepInvariants(
        uint160 sqrtPriceRaw,
        uint160 sqrtPriceTargetRaw,
        uint128 liquidity,
        int256 amountRemaining,
        uint24 feePips
    ) external pure {
        require(sqrtPriceRaw > 0);
        require(sqrtPriceTargetRaw > 0);
        require(feePips > 0);
        require(feePips < 1e6);

        (FixedPoint96.uq64x96 memory sqrtQ, uint256 amountIn, uint256 amountOut, uint256 feeAmount) =
            SwapMath.computeSwapStep(
                FixedPoint96.uq64x96(sqrtPriceRaw),
                FixedPoint96.uq64x96(sqrtPriceTargetRaw),
                liquidity,
                amountRemaining,
                feePips
            );

        assert(amountIn <= uint256(-1) - feeAmount);

        if (amountRemaining < 0) {
            assert(amountOut <= uint256(-amountRemaining));
        } else {
            assert(amountIn + feeAmount <= uint256(amountRemaining));
        }

        if (sqrtPriceRaw == sqrtPriceTargetRaw) {
            assert(amountIn == 0);
            assert(amountOut == 0);
            assert(feeAmount == 0);
            assert(sqrtQ._x == sqrtPriceTargetRaw);
        }

        // didn't reach price target, entire amount must be consumed
        if (sqrtQ._x != sqrtPriceTargetRaw) {
            if (amountRemaining < 0) assert(amountOut == uint256(-amountRemaining));
            else assert(amountIn + feeAmount == uint256(amountRemaining));
        }

        // next price is between price and price target
        if (sqrtPriceTargetRaw <= sqrtPriceRaw) {
            assert(sqrtQ._x <= sqrtPriceRaw);
            assert(sqrtQ._x >= sqrtPriceTargetRaw);
        } else {
            assert(sqrtQ._x >= sqrtPriceRaw);
            assert(sqrtQ._x <= sqrtPriceTargetRaw);
        }
    }
}
