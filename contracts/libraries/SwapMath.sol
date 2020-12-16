// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import '@uniswap/lib/contracts/libraries/FullMath.sol';

import './FixedPoint96.sol';
import './FixedPoint128.sol';
import './SqrtPriceMath.sol';

library SwapMath {
    using SafeMath for uint256;

    function computeSwapStep(
        FixedPoint96.uq64x96 memory sqrtP,
        FixedPoint96.uq64x96 memory sqrtQTarget,
        uint128 liquidity,
        int256 amountSpecifiedMax,
        uint24 feePips,
        bool zeroForOne
    )
        internal
        pure
        returns (
            FixedPoint96.uq64x96 memory sqrtQ,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        uint256 amountInMax = amountSpecifiedMax > 0 ? uint256(amountSpecifiedMax) : 0;
        uint256 amountOutMax = amountSpecifiedMax < 0 ? uint256(-amountSpecifiedMax) : 0;

        if (amountInMax > 0) {
            uint256 amountInMaxLessFee = FullMath.mulDiv(amountInMax, 1e6 - feePips, 1e6);
            sqrtQ = SqrtPriceMath.getNextPriceFromInput(sqrtP, liquidity, amountInMaxLessFee, zeroForOne);
        } else {
            sqrtQ = SqrtPriceMath.getNextPriceFromOutput(sqrtP, liquidity, amountOutMax, zeroForOne);
        }

        // get the input/output amounts
        if (zeroForOne) {
            assert(sqrtP._x >= sqrtQTarget._x);

            // if we've overshot the target, cap at the target
            if (sqrtQ._x < sqrtQTarget._x) sqrtQ = sqrtQTarget;

            amountIn = SqrtPriceMath.getAmount0Delta(sqrtP, sqrtQ, liquidity, true);
            amountOut = SqrtPriceMath.getAmount1Delta(sqrtQ, sqrtP, liquidity, false);
        } else {
            assert(sqrtP._x <= sqrtQTarget._x);

            // if we've overshot the target, cap at the target
            if (sqrtQ._x > sqrtQTarget._x) sqrtQ = sqrtQTarget;

            amountIn = SqrtPriceMath.getAmount1Delta(sqrtP, sqrtQ, liquidity, true);
            amountOut = SqrtPriceMath.getAmount0Delta(sqrtQ, sqrtP, liquidity, false);
        }

        if (amountInMax > 0) {
            // a max input amount was specified, ensure the calculated input amount is < it
            assert(amountIn < amountInMax);
        } else {
            // a max output amount was specified, cap
            if (amountOut > amountOutMax) amountOut = amountOutMax;
        }

        if (sqrtQ._x != sqrtQTarget._x) {
            if (amountInMax > 0) {
                // ensure that we can pay for the calculated input amount
                assert(SqrtPriceMath.mulDivRoundingUp(amountIn, 1e6, 1e6 - feePips) <= amountInMax);
                // we didn't reach the target, so take the remainder of the maximum input as fee
                feeAmount = amountInMax - amountIn;
            } else {
                // an exact output amount was specified, make sure we reached it
                assert(amountOut == amountOutMax);
                feeAmount = SqrtPriceMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
            }
        } else {
            feeAmount = SqrtPriceMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
            if (amountInMax > 0) assert(amountIn.add(feeAmount) <= amountInMax);
        }
    }
}
