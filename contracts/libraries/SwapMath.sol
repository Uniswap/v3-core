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
        uint160 sqrtPX96,
        uint160 sqrtPTargetX96,
        uint128 liquidity,
        int256 amountRemaining,
        uint24 feePips
    )
        internal
        pure
        returns (
            uint160 sqrtQX96,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        bool zeroForOne = sqrtPX96 >= sqrtPTargetX96;
        bool exactIn = amountRemaining >= 0;

        if (exactIn) {
            uint256 amountInMaxLessFee = FullMath.mulDiv(uint256(amountRemaining), 1e6 - feePips, 1e6);
            sqrtQX96 = SqrtPriceMath.getNextPriceFromInput(sqrtPX96, liquidity, amountInMaxLessFee, zeroForOne);
        } else {
            sqrtQX96 = SqrtPriceMath.getNextPriceFromOutput(sqrtPX96, liquidity, uint256(-amountRemaining), zeroForOne);
        }

        // get the input/output amounts
        if (zeroForOne) {
            // if we've overshot the target, cap at the target
            if (sqrtQX96 < sqrtPTargetX96) sqrtQX96 = sqrtPTargetX96;

            amountIn = SqrtPriceMath.getAmount0Delta(sqrtPX96, sqrtQX96, liquidity, true);
            amountOut = SqrtPriceMath.getAmount1Delta(sqrtQX96, sqrtPX96, liquidity, false);
        } else {
            // if we've overshot the target, cap at the target
            if (sqrtQX96 > sqrtPTargetX96) sqrtQX96 = sqrtPTargetX96;

            amountIn = SqrtPriceMath.getAmount1Delta(sqrtPX96, sqrtQX96, liquidity, true);
            amountOut = SqrtPriceMath.getAmount0Delta(sqrtQX96, sqrtPX96, liquidity, false);
        }

        // cap the output amount to not exceed the remaining output amount
        if (!exactIn && amountOut > uint256(-amountRemaining)) {
            amountOut = uint256(-amountRemaining);
        }

        if (exactIn && sqrtQX96 != sqrtPTargetX96) {
            // we didn't reach the target, so take the remainder of the maximum input as fee
            feeAmount = uint256(amountRemaining) - amountIn;
        } else {
            feeAmount = SqrtPriceMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
        }
    }
}
