// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import '../libraries/PriceMath.sol';

contract PriceMathTest {
    function getInputToRatio(
        uint112 reserveIn,
        uint112 reserveOut,
        uint16 lpFee,
        FixedPoint.uq112x112 memory nextPrice,
        FixedPoint.uq112x112 memory nextPriceInverse,
        bool zeroForOne
    ) public pure returns (uint112 amountIn) {
        return PriceMath.getInputToRatio(reserveIn, reserveOut, lpFee, nextPrice, nextPriceInverse, zeroForOne);
    }

    function getAmountOut(
        uint112 reserveIn,
        uint112 reserveOut,
        uint16 lpFee,
        uint112 amountIn
    ) external pure returns (uint112) {
        return PriceMath.getAmountOut(reserveIn, reserveOut, lpFee, amountIn);
    }

    function getGasCostOfGetInputToRatio(
        uint112 reserveIn,
        uint112 reserveOut,
        uint16 lpFee,
        FixedPoint.uq112x112 memory nextPrice,
        FixedPoint.uq112x112 memory nextPriceInverse,
        bool zeroForOne
    ) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        PriceMath.getInputToRatio(reserveIn, reserveOut, lpFee, nextPrice, nextPriceInverse, zeroForOne);
        return gasBefore - gasleft();
    }
}
