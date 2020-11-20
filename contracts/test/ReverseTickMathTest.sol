// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

import '../libraries/ReverseTickMath.sol';

contract ReverseTickMathTest {
    function getTickFromPrice(
        FixedPoint128.uq128x128 memory price,
        int16 lowerBound,
        int16 upperBound
    ) external pure returns (int16 tick) {
        return ReverseTickMath.getTickFromPrice(price, lowerBound, upperBound);
    }

    function getGasCostOfGetTickFromPrice(
        FixedPoint128.uq128x128 memory price,
        int16 lowerBound,
        int16 upperBound
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        ReverseTickMath.getTickFromPrice(price, lowerBound, upperBound);
        return gasBefore - gasleft();
    }
}
