// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import '../libraries/PriceMath.sol';

contract PriceMathTest {
    function getAmountOut(
        uint112 reserveIn,
        uint112 reserveOut,
        uint112 amountIn
    ) external pure returns (uint112) {
        return PriceMath.getAmountOut(reserveIn, reserveOut, amountIn);
    }

    function getVirtualReservesAtPrice(
        FixedPoint.uq112x112 memory price,
        uint256 liquidity,
        bool roundUp
    ) external pure returns (uint112 reserve0, uint112 reserve1) {
        return PriceMath.getVirtualReservesAtPrice(price, liquidity, roundUp);
    }

    function getInputToRatio(
        uint112 reserve0,
        uint112 reserve1,
        uint112 liquidity,
        FixedPoint.uq112x112 memory priceTarget, // always reserve1/reserve0
        uint16 lpFee,
        bool zeroForOne
    ) external pure returns (uint112 amountIn, uint112 amountOut) {
        return PriceMath.getInputToRatio(reserve0, reserve1, liquidity, priceTarget, lpFee, zeroForOne);
    }

    function getGasCostOfGetInputToRatio(
        uint112 reserve0,
        uint112 reserve1,
        uint112 liquidity,
        FixedPoint.uq112x112 memory priceTarget,
        uint16 lpFee,
        bool zeroForOne
    ) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        PriceMath.getInputToRatio(reserve0, reserve1, liquidity, priceTarget, lpFee, zeroForOne);
        return gasBefore - gasleft();
    }
}
