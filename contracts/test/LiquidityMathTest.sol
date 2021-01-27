// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/LiquidityMath.sol';

contract LiquidityMathTest {
    function addDelta(uint128 x, int128 y) external pure returns (uint128 z) {
        return LiquidityMath.addDelta(x, y);
    }

    function getGasCostOfAddDelta(uint128 x, int128 y) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        LiquidityMath.addDelta(x, y);
        return gasBefore - gasleft();
    }

    function subDelta(uint128 x, int128 y) external pure returns (uint128 z) {
        return LiquidityMath.subDelta(x, y);
    }

    function getGasCostOfSubDelta(uint128 x, int128 y) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        LiquidityMath.subDelta(x, y);
        return gasBefore - gasleft();
    }
}
