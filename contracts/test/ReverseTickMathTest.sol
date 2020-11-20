// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import '../libraries/ReverseTickMath.sol';

contract ReverseTickMathTest {
    function getTickFromPrice(
        FixedPoint.uq112x112 memory price,
        int16 lowerBound,
        int16 upperBound
    ) external pure returns (int16 tick) {
        return ReverseTickMath.getTickFromPrice(price, lowerBound, upperBound);
    }

    function getGasCostOfGetTickFromPrice(
        FixedPoint.uq112x112 memory price,
        int16 lowerBound,
        int16 upperBound
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        ReverseTickMath.getTickFromPrice(price, lowerBound, upperBound);
        return gasBefore - gasleft();
    }
}
