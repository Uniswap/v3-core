// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import '../libraries/TickMath.sol';

contract TickMathEchidnaTest {
    using FixedPoint for *;

    function getRatioAtTick(int16 tick) external pure {
        require(tick < TickMath.MAX_TICK && tick > TickMath.MIN_TICK);

        assert(TickMath.getRatioAtTick(tick) == TickMath.getRatioAtTick(-tick).reciprocal());
    }
}
