// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';

import './FixedPoint64.sol';
import './FixedPoint128.sol';
import './SqrtPriceMath.sol';

library SwapMath {
    function computeSwap(
        FixedPoint128.uq128x128 memory price,
        FixedPoint128.uq128x128 memory target,
        uint128 liquidity,
        uint256 amountInMax,
        uint24 feePips,
        bool zeroForOne
    )
        internal
        pure
        returns (
            FixedPoint128.uq128x128 memory priceAfter,
            uint256 amountIn,
            uint256 amountOut
        )
    {
        FixedPoint64.uq64x64 memory sqrtP = FixedPoint64.uq64x64(uint128(Babylonian.sqrt(price._x)));
        FixedPoint64.uq64x64 memory targetSqrtQ = FixedPoint64.uq64x64(uint128(Babylonian.sqrt(target._x)));

        uint256 amountInLessFee = FullMath.mulDiv(amountInMax, 1e6 - feePips, 1e6);

        FixedPoint64.uq64x64 memory sqrtQ = SqrtPriceMath.getPriceAfterSwap(
            sqrtP,
            liquidity,
            amountInLessFee,
            zeroForOne
        );

        // get the output amount, rounding down
        if (zeroForOne) {
            assert(price._x >= target._x);

            if (sqrtQ._x < targetSqrtQ._x) {
                sqrtQ = targetSqrtQ;
            }

            amountIn = SqrtPriceMath.getAmount0Delta(sqrtP, sqrtQ, liquidity, true);
            amountOut = SqrtPriceMath.getAmount1Delta(sqrtQ, sqrtP, liquidity, false);
        } else {
            assert(price._x <= target._x);

            if (sqrtQ._x > targetSqrtQ._x) {
                sqrtQ = targetSqrtQ;
            }

            amountIn = SqrtPriceMath.getAmount1Delta(sqrtP, sqrtQ, liquidity, true);
            amountOut = SqrtPriceMath.getAmount0Delta(sqrtQ, sqrtP, liquidity, false);
        }

        priceAfter = sqrtQ._x == targetSqrtQ._x ? target : FixedPoint128.uq128x128(uint256(sqrtQ._x)**2);

        amountIn = SqrtPriceMath.mulDivRoundingUp(amountIn, 1e6, 1e6 - feePips);
        if (amountIn > amountInMax) {
            // todo: this is the cause of the failing test.
            amountIn = amountInMax;
        }
    }
}
