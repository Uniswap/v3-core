// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './TickMath.sol';
import './SqrtPriceMath.sol';

// returns and takes sqrt prices for 1 bips ticks
library SqrtTickMath {
    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160) {
        return uint160(SqrtPriceMath.divRoundingUp(TickMath.getRatioAtTick(tick), 1 << 32));
    }

    function getTickAtSqrtRatio(uint160 sqrtPX96) internal pure returns (int24) {
        return TickMath.getTickAtRatio(uint256(sqrtPX96) << 32);
    }
}
