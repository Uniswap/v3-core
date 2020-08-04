// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.11;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import '../libraries/PriceMath.sol';

contract PriceMathTest {
    function getTradeToRatio(
        uint112 reserveIn, uint112 reserveOut, uint16 lpFee, FixedPoint.uq112x112 memory inOutRatio
    ) public pure returns (uint112 amountIn) {
        return PriceMath.getTradeToRatio(reserveIn, reserveOut, lpFee, inOutRatio);
    }
}
