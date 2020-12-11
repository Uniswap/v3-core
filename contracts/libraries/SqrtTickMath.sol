// TODO consolidate this function into another library at some point and add tests
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import './FixedPoint64.sol';
import './TickMath.sol';

// returns and takes sqrt prices for 1 bips ticks
library SqrtTickMath {
    function getSqrtRatioAtTick(int24 tick) internal pure returns (FixedPoint64.uq64x64 memory) {
        uint256 ratio = TickMath.getRatioAtTick(tick) >> FixedPoint64.RESOLUTION;
        return FixedPoint64.uq64x64(uint128(ratio));
    }

    function getTickAtSqrtRatio(FixedPoint64.uq64x64 memory sqrtP) internal pure returns (int24) {
        return TickMath.getTickAtRatio(uint256(sqrtP._x) << 64);
    }
}
