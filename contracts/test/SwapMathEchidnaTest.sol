// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/FixedPoint128.sol';
import '../libraries/SwapMath.sol';

contract SwapMathEchidnaTest {
    function checkComputeSwapStepInvariants(
        uint160 sqrtPriceRaw,
        uint160 sqrtPriceTargetRaw,
        uint128 liquidity,
        int256 amount,
        uint24 feePips
    ) external pure {
        require(sqrtPriceRaw > 0);
        require(sqrtPriceTargetRaw > 0);
        require(feePips > 0);
        require(feePips < 1e6);

        bool zeroForOne = sqrtPriceRaw >= sqrtPriceTargetRaw;

        require(amount != 0);

        (FixedPoint96.uq64x96 memory sqrtQ, uint256 amountIn, uint256 amountOut, uint256 feeAmount) = SwapMath
            .computeSwapStep(
            FixedPoint96.uq64x96(sqrtPriceRaw),
            FixedPoint96.uq64x96(sqrtPriceTargetRaw),
            liquidity,
            amount,
            feePips,
            zeroForOne
        );

        if (sqrtPriceRaw != sqrtPriceTargetRaw) {
            assert(feeAmount > 0);
            // amountIn is not necessarily gt 0, the entire amount in can be taken as a fee
        }

        if (zeroForOne) {
            assert(sqrtQ._x <= sqrtPriceRaw);
            assert(sqrtQ._x >= sqrtPriceTargetRaw);
        } else {
            assert(sqrtQ._x >= sqrtPriceRaw);
            assert(sqrtQ._x <= sqrtPriceTargetRaw);
        }

        if (amount < 0) {
            assert(amountOut <= uint256(-amount));
        } else {
            assert(amountIn + feeAmount <= uint256(amount));
        }
    }
}
