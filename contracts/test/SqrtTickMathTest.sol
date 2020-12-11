// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

import '../libraries/FixedPoint64.sol';
import '../libraries/SqrtTickMath.sol';

contract SqrtTickMathTest {
    function getSqrtRatioAtTick(int24 tick) external pure returns (FixedPoint64.uq64x64 memory) {
        return SqrtTickMath.getSqrtRatioAtTick(tick);
    }

    function getTickAtSqrtRatio(FixedPoint64.uq64x64 memory sqrtP) external pure returns (int24) {
        return SqrtTickMath.getTickAtSqrtRatio(sqrtP);
    }
}
