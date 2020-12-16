// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/TickMath.sol';

contract TickMathEchidnaTest {
    // uniqueness and increasing order
    function checkGetRatioAtTickInvariants(int24 tick) external pure {
        uint256 ratio = TickMath.getRatioAtTick(tick);
        assert(TickMath.getRatioAtTick(tick - 1) < ratio && ratio < TickMath.getRatioAtTick(tick + 1));
    }

    // the ratio is always between the returned tick and the returned tick+1
    function checkGetTickAtRatioInvariants(uint256 ratio) external pure {
        int24 tick = TickMath.getTickAtRatio(ratio);
        assert(ratio >= TickMath.getRatioAtTick(tick) && ratio < TickMath.getRatioAtTick(tick + 1));
    }
}
