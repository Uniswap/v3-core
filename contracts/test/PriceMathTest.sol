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
        FixedPoint.uq112x112 memory inOutRatio
    ) public pure returns (uint112 amountIn) {
        return PriceMath.getInputToRatio(reserveIn, reserveOut, lpFee, inOutRatio);
    }

    function getGasCostOfGetInputToRatio(
        uint112 reserveIn,
        uint112 reserveOut,
        uint16 lpFee,
        FixedPoint.uq112x112 memory inOutRatio
    ) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        PriceMath.getInputToRatio(reserveIn, reserveOut, lpFee, inOutRatio);
        return gasBefore - gasleft();
    }
}
