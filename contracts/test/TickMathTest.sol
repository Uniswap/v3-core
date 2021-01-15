// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/TickMath.sol';

contract TickMathTest {
    function getRatioAtTick(int24 tick) public pure returns (uint256) {
        return TickMath.getRatioAtTick(tick);
    }

    function getRatioAtTickGasUsed(int24 tick) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        TickMath.getRatioAtTick(tick);
        uint256 gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }

    function getTickAtRatio(uint256 price) public pure returns (int24 tick) {
        return TickMath.getTickAtRatio(price);
    }

    function getTickAtRatioGasUsed(uint256 price) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        TickMath.getTickAtRatio(price);
        uint256 gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }
}
