// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './FullMath.sol';
import './FixedPoint96.sol';

library LiquidityFromAmounts {
    /// @notice Gets the liquidityDelta delta between two prices for a certain amount1 given.
    /// Inverse function of `SqrtPriceMath.getAmount0Delta`
    /// @dev Calculates amount0 * (sqrt(upper) * sqrt(lower)) / (sqrt(upper) - sqrt(lower)).
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param amount0 The amount0 being sent in
    /// @param liquidityDelta The amount of returned liquidity
    function getLiquidityDeltaForAmount0(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 amount0
    ) internal pure returns (uint256 liquidityDelta) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        uint256 numDenom = FullMath.mulDivRoundingUp(sqrtRatioBX96, sqrtRatioAX96, sqrtRatioBX96 - sqrtRatioAX96);
        return FullMath.mulDiv(amount0, numDenom, FixedPoint96.Q96); // round up here for prec errors
    }

    /// @notice Gets the liquidityDelta delta between two prices for a certain amount1 given
    /// Inverse function of `SqrtPriceMath.getAmount1Delta`
    /// @dev Calculates amount1 / (sqrt(upper) - sqrt(lower)).
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param amount1 The amount1 being sent in
    /// @param liquidityDelta The amount of returned liquidity
    function getLiquidityDeltaForAmount1(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 amount1
    ) internal pure returns (uint256 liquidityDelta) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        return FullMath.mulDiv(amount1, FixedPoint96.Q96, sqrtRatioBX96 - sqrtRatioAX96);
    }
}
