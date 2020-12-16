// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import '../libraries/FixedPoint128.sol';
import '../libraries/TickMath.sol';

contract TickMathTest {
    function getRatioAtTick(int24 tick) public pure returns (FixedPoint128.uq128x128 memory) {
        return FixedPoint128.uq128x128(TickMath.getRatioAtTick(tick));
    }

    function getRatioAtTickGasUsed(int24 tick) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        TickMath.getRatioAtTick(tick);
        uint256 gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }

    function getTickAtRatio(FixedPoint128.uq128x128 memory price) public pure returns (int24 tick) {
        return TickMath.getTickAtRatio(price._x);
    }

    function getTickAtRatioGasUsed(FixedPoint128.uq128x128 memory price) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        TickMath.getTickAtRatio(price._x);
        uint256 gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }
}
