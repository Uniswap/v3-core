// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '../libraries/SqrtTickMath.sol';

contract SqrtTickMathEchidnaTest {
    // uniqueness and increasing order
    function checkGetSqrtRatioAtTickInvariants(int24 tick) external pure {
        uint128 ratio = SqrtTickMath.getSqrtRatioAtTick(tick)._x;
        assert(
            SqrtTickMath.getSqrtRatioAtTick(tick - 1)._x < ratio && ratio < SqrtTickMath.getSqrtRatioAtTick(tick + 1)._x
        );
    }

    // the ratio is always between the returned tick and the returned tick+1
    function checkGetTickAtSqrtRatioInvariants(uint128 ratio) external pure {
        int24 tick = SqrtTickMath.getTickAtSqrtRatio(FixedPoint64.uq64x64(ratio));
        assert(
            ratio >= SqrtTickMath.getSqrtRatioAtTick(tick)._x && ratio < SqrtTickMath.getSqrtRatioAtTick(tick + 1)._x
        );
    }
}
