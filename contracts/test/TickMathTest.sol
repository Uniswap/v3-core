// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

import '../interfaces/ITickMath.sol';

import '../libraries/FixedPoint128.sol';

contract TickMathTest {
    ITickMath public immutable tickMath;

    constructor(ITickMath tickMath_) public {
        tickMath = tickMath_;
    }

    function getRatioAtTick(int24 tick) public view returns (FixedPoint128.uq128x128 memory) {
        return FixedPoint128.uq128x128(tickMath.getRatioAtTick(tick));
    }

    function getRatioAtTickGasUsed(int24 tick) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        tickMath.getRatioAtTick(tick);
        uint256 gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }

    function getTickAtRatio(FixedPoint128.uq128x128 memory price) public view returns (int24 tick) {
        return tickMath.getTickAtRatio(price._x);
    }

    function getTickAtRatioGasUsed(FixedPoint128.uq128x128 memory price) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        tickMath.getTickAtRatio(price._x);
        uint256 gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }
}
