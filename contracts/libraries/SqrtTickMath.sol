// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import './FixedPoint64.sol';
import './TickMath.sol';

// returns and takes sqrt prices for 1 bips ticks
library SqrtTickMath {
    int24 internal constant MIN_TICK = -689197;
    int24 internal constant MAX_TICK = 689197;

    function getSqrtRatioAtTick(int24 tick) internal pure returns (FixedPoint64.uq64x64 memory) {
        require(tick >= MIN_TICK && tick <= MAX_TICK, 'SqrtTickMath::getSqrtRatioAtTick: invalid tick');
        uint256 ratio = TickMath.getRatioAtTick(tick);
        // truncate, rounding up
        return FixedPoint64.uq64x64(uint128(ratio >> FixedPoint64.RESOLUTION) + (ratio % FixedPoint64.Q64 > 0 ? 1 : 0));
    }

    function getTickAtSqrtRatio(FixedPoint64.uq64x64 memory sqrtP) internal pure returns (int24) {
        require(
            sqrtP._x >= 19997 && sqrtP._x <= 17017438448674477402236614712524090,
            'SqrtTickMath::getSqrtRatioAtTick: invalid sqrtP'
        );
        return TickMath.getTickAtRatio(uint256(sqrtP._x) << 64);
    }
}
