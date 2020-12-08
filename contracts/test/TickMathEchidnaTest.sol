// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '../libraries/TickMath.sol';

contract TickMathEchidnaTest {
    // uniqueness and increasing order
    function checkGetRatioAtTickInvariants(int24 tick) public pure {
        uint256 ratio = TickMath.getRatioAtTick(tick);
        assert(TickMath.getRatioAtTick(tick - 1) < ratio && ratio < TickMath.getRatioAtTick(tick + 1));
    }

    // the ratio is always between the returned tick and the returned tick+1
    function checkGetTickAtRatioInvariants(uint256 ratio) public pure {
        int24 tick = TickMath.getTickAtRatio(ratio);
        assert(ratio >= TickMath.getRatioAtTick(tick) && ratio < TickMath.getRatioAtTick(tick + 1));
    }
}
