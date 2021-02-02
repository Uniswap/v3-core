// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './TickMath.sol';
import './LowGasSafeMath.sol';

/// @title Math library for computing sqrt(price) from ticks
/// @notice Computes sqrt(price) from ticks of size 1.0001 as fixed point Q64.96 numbers
library SqrtTickMath {
    // these values come from log base 1.0001 of 2**128
    // i.e. the assumption is the price cannot exceed 2**128 or 2**-128 because the total supply of both tokens
    // is assumed to be less than 2**128
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    /// @notice Gets the sqrt(price) associated with a given tick as a fixed point Q64.96 number
    /// @param tick the tick for which to compute the sqrt price
    /// @return the sqrt price for ticks of size 1.0001
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160) {
        return uint160(LowGasSafeMath.divRoundingUp(TickMath.getRatioAtTick(tick), 1 << 32));
    }

    /// @notice Gets the tick from the sqrt(price)
    /// @param sqrtPX96 price from which to compute the tick
    /// @return the greatest tick s.t. getSqrtRatioAtTick(tick) is less than or equal to sqrtPX96
    function getTickAtSqrtRatio(uint160 sqrtPX96) internal pure returns (int24) {
        return TickMath.getTickAtRatio(uint256(sqrtPX96) << 32);
    }
}
