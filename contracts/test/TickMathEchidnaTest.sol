// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import '../libraries/TickMath.sol';

contract TickMathEchidnaTest {
    using FixedPoint for *;

    function getRatioAtTickInvariant(int16 tick) external pure {
        require(tick >= TickMath.MIN_TICK && tick < TickMath.MAX_TICK);

        assert(TickMath.getRatioAtTick(tick)._x == TickMath.getRatioAtTick(-tick).reciprocal()._x);
    }
}
