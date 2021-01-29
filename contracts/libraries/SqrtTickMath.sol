// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './TickMath.sol';
import './LowGasSafeMath.sol';

// returns and takes sqrt prices for 1 bips ticks
library SqrtTickMath {
    // these values come from log base 1.0001 of 2**128
    // i.e. the assumption is the price cannot exceed 2**128 or 2**-128 because the total supply of both tokens
    // is assumed to be less than 2**128
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160) {
        return uint160(LowGasSafeMath.divRoundingUp(TickMath.getRatioAtTick(tick), 1 << 32));
    }

    function getTickAtSqrtRatio(uint160 sqrtPX96) internal pure returns (int24) {
        return TickMath.getTickAtRatio(uint256(sqrtPX96) << 32);
    }
}
