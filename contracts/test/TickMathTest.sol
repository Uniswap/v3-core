// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

import '../libraries/FixedPoint128.sol';
import '../libraries/TickMath.sol';

contract TickMathTest {
    function MIN_TICK() external pure returns (int24) {
        return TickMath.MIN_TICK;
    }

    function MAX_TICK() external pure returns (int24) {
        return TickMath.MAX_TICK;
    }

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
