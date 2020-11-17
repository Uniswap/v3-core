// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

import '../codegen/GeneratedTickMath.sol';
import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

contract GeneratedTickMathTest {
    GeneratedTickMath private immutable tickMath;

    constructor(GeneratedTickMath tickMath_) public {
        tickMath = tickMath_;
    }

    function getPrice(int16 tick) public view returns (FixedPoint.uq112x112 memory) {
        return FixedPoint.uq112x112(uint224(tickMath.getRatioAtTick(tick)));
    }

    function getGasUsed(int16 tick) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        tickMath.getRatioAtTick(tick);
        uint256 gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }
}
