// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './FullMath.sol';
import './SqrtPriceMath.sol';

/// @title Computes the result of swap within ticks
/// @notice Contains methods for computing the result of a swap within a single tick price range, i.e. a single tick.
library SwapMath {
    /// @notice Compute the result of swapping some amount in or amount out given the parameters of the swap
    /// @param sqrtPX96 the current sqrt price of the pair
    /// @param sqrtPTargetX96 the price that cannot be exceeded, from which the direction of the swap is inferred
    /// @param liquidity the usable liquidity
    /// @param amountRemaining how much input or output amount is remaining to be swapped in/out
    /// @param feePips the fee taken from the input amount in expressed pips
    /// @return sqrtQX96 the price after swapping the amount in/out, not to exceed the price target
    /// @return amountIn the amount to be swapped in, of either token0 or token1, based on the direction of the swap
    /// @return amountOut the amount to be swapped in, of either token0 or token1, based on the direction of the swap
    /// @return feeAmount the amount of the input that should be taken as a fee
    /// @dev The fee plus the amount in will never exceed the amount remaining if positive.
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
            uint256 amountRemainingLessFee = FullMath.mulDiv(uint256(amountRemaining), 1e6 - feePips, 1e6);
            amountIn = zeroForOne
                ? SqrtPriceMath.getAmount0Delta(sqrtPX96, sqrtPTargetX96, liquidity, true)
                : SqrtPriceMath.getAmount1Delta(sqrtPX96, sqrtPTargetX96, liquidity, true);
            if (amountRemainingLessFee >= amountIn) sqrtQX96 = sqrtPTargetX96;
            else
                sqrtQX96 = SqrtPriceMath.getNextSqrtPriceFromInput(
                    sqrtPX96,
                    liquidity,
                    amountRemainingLessFee,
                    zeroForOne
                );
        } else {
            amountOut = zeroForOne
                ? SqrtPriceMath.getAmount1Delta(sqrtPTargetX96, sqrtPX96, liquidity, false)
                : SqrtPriceMath.getAmount0Delta(sqrtPTargetX96, sqrtPX96, liquidity, false);
            if (uint256(-amountRemaining) >= amountOut) sqrtQX96 = sqrtPTargetX96;
            else
                sqrtQX96 = SqrtPriceMath.getNextSqrtPriceFromOutput(
                    sqrtPX96,
                    liquidity,
                    uint256(-amountRemaining),
                    zeroForOne
                );
        }

        bool max = sqrtPTargetX96 == sqrtQX96;

        // get the input/output amounts
        if (zeroForOne) {
            amountIn = max && exactIn ? amountIn : SqrtPriceMath.getAmount0Delta(sqrtPX96, sqrtQX96, liquidity, true);
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount1Delta(sqrtQX96, sqrtPX96, liquidity, false);
        } else {
            amountIn = max && exactIn ? amountIn : SqrtPriceMath.getAmount1Delta(sqrtPX96, sqrtQX96, liquidity, true);
            amountOut = max && !exactIn
                ? amountOut
                : SqrtPriceMath.getAmount0Delta(sqrtQX96, sqrtPX96, liquidity, false);
        }

        // cap the output amount to not exceed the remaining output amount
        if (!exactIn && amountOut > uint256(-amountRemaining)) {
            amountOut = uint256(-amountRemaining);
        }

        if (exactIn && sqrtQX96 != sqrtPTargetX96) {
            // we didn't reach the target, so take the remainder of the maximum input as fee
            feeAmount = uint256(amountRemaining) - amountIn;
        } else {
            feeAmount = FullMath.mulDivRoundingUp(amountIn, feePips, 1e6 - feePips);
        }
    }
}
