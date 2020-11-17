// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '../codegen/GeneratedTickMath.sol';

contract GeneratedTickMathTest {
    function getPrice(int16 tick) public pure returns (uint256) {
        return GeneratedTickMath.getRatioAtTick(tick);
    }

    function getGasUsed(int16 tick) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        GeneratedTickMath.getRatioAtTick(tick);
        uint256 gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }
}
