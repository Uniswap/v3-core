// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './FixedPoint96.sol';
import './TickMath.sol';

// returns and takes sqrt prices for 1 bips ticks
library SqrtTickMath {
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    function getSqrtRatioAtTick(int24 tick) internal pure returns (FixedPoint96.uq64x96 memory) {
        uint256 ratio = TickMath.getRatioAtTick(tick);
        // truncate, rounding up
        return FixedPoint96.uq64x96(uint160(ratio >> 32) + (ratio % (1 << 32) > 0 ? 1 : 0));
    }

    function getTickAtSqrtRatio(FixedPoint96.uq64x96 memory sqrtP) internal pure returns (int24) {
        return TickMath.getTickAtRatio(uint256(sqrtP._x) << 32);
    }
}
