// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/SqrtTickMath.sol';

contract SqrtTickMathEchidnaTest {
    // uniqueness and increasing order
    function checkGetSqrtRatioAtTickInvariants(int24 tick) external pure {
        uint160 ratio = SqrtTickMath.getSqrtRatioAtTick(tick);
        assert(SqrtTickMath.getSqrtRatioAtTick(tick - 1) < ratio && ratio < SqrtTickMath.getSqrtRatioAtTick(tick + 1));
    }

    // the ratio is always between the returned tick and the returned tick+1
    function checkGetTickAtSqrtRatioInvariants(uint160 ratio) external pure {
        int24 tick = SqrtTickMath.getTickAtSqrtRatio(ratio);
        assert(ratio >= SqrtTickMath.getSqrtRatioAtTick(tick) && ratio < SqrtTickMath.getSqrtRatioAtTick(tick + 1));
    }
}
