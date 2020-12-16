// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import '../libraries/FixedPoint96.sol';
import '../libraries/SqrtTickMath.sol';

contract SqrtTickMathTest {
    function getSqrtRatioAtTick(int24 tick) external pure returns (FixedPoint96.uq64x96 memory) {
        return SqrtTickMath.getSqrtRatioAtTick(tick);
    }

    function getTickAtSqrtRatio(FixedPoint96.uq64x96 memory sqrtP) external pure returns (int24) {
        return SqrtTickMath.getTickAtSqrtRatio(sqrtP);
    }
}
