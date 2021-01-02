// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './SafeMath.sol';
import './FullMath.sol';

import './FixedPoint128.sol';
import './SqrtPriceMath.sol';

library SwapMath {
    using SafeMath for uint256;

    // compute the state changes for the swap step
    function computeSwapStep(
        uint160 sqrtP,
        uint160 sqrtPTarget,
        uint128 liquidity,
        int256 amountRemaining,
        uint24 feePips
    )
        internal
        pure
        returns (
            uint160 sqrtQ,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        bool zeroForOne = sqrtP >= sqrtPTarget;
        bool exactIn = amountRemaining >= 0;

        if (exactIn) {
            uint256 amountInMaxLessFee = FullMath.mulDiv(uint256(amountRemaining), 1e6 - feePips, 1e6);
            sqrtQ = SqrtPriceMath.getNextPriceFromInput(sqrtP, liquidity, amountInMaxLessFee, zeroForOne);
        } else {
            sqrtQ = SqrtPriceMath.getNextPriceFromOutput(sqrtP, liquidity, uint256(-amountRemaining), zeroForOne);
        }

        // get the input/output amounts
        if (zeroForOne) {
            // if we've overshot the target, cap at the target
            if (sqrtQ < sqrtPTarget) sqrtQ = sqrtPTarget;

            amountIn = SqrtPriceMath.getAmount0Delta(sqrtP, sqrtQ, liquidity, true);
            amountOut = SqrtPriceMath.getAmount1Delta(sqrtQ, sqrtP, liquidity, false);
        } else {
            // if we've overshot the target, cap at the target
            if (sqrtQ > sqrtPTarget) sqrtQ = sqrtPTarget;

            amountIn = SqrtPriceMath.getAmount1Delta(sqrtP, sqrtQ, liquidity, true);
            amountOut = SqrtPriceMath.getAmount0Delta(sqrtQ, sqrtP, liquidity, false);
        }

        // cap the output amount to not exceed the remaining output amount
        if (!exactIn && amountOut > uint256(-amountRemaining)) {
            amountOut = uint256(-amountRemaining);
        }

        if (exactIn && sqrtQ != sqrtPTarget) {
            // we didn't reach the target, so take the remainder of the maximum input as fee
            feeAmount = uint256(amountRemaining) - amountIn;
        } else {
            feeAmount = SqrtPriceMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
        }
    }
}
