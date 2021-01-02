// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/SqrtTickMath.sol';

contract SqrtTickMathTest {
    function getSqrtRatioAtTick(int24 tick) external pure returns (uint160) {
        return SqrtTickMath.getSqrtRatioAtTick(tick);
    }

    function getTickAtSqrtRatio(uint160 sqrtP) external pure returns (int24) {
        return SqrtTickMath.getTickAtSqrtRatio(sqrtP);
    }
}
