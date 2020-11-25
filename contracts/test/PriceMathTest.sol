// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '../libraries/PriceMath.sol';

contract PriceMathTest {
    function getAmountOut(
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 amountIn
    ) external pure returns (uint256) {
        return PriceMath.getAmountOut(reserveIn, reserveOut, amountIn);
    }

    function getVirtualReservesAtPrice(
        FixedPoint128.uq128x128 memory price,
        uint128 liquidity,
        bool roundUp
    ) external pure returns (uint256 reserve0, uint256 reserve1) {
        return PriceMath.getVirtualReservesAtPrice(price, liquidity, roundUp);
    }

    function getInputToRatio(
        uint256 reserve0,
        uint256 reserve1,
        uint128 liquidity,
        FixedPoint128.uq128x128 memory priceTarget, // always reserve1/reserve0
        uint24 lpFee,
        bool zeroForOne
    ) external pure returns (uint256 amountIn, uint256 amountOut) {
        return PriceMath.getInputToRatio(reserve0, reserve1, liquidity, priceTarget, lpFee, zeroForOne);
    }

    function getGasCostOfGetInputToRatio(
        uint256 reserve0,
        uint256 reserve1,
        uint128 liquidity,
        FixedPoint128.uq128x128 memory priceTarget, // always reserve1/reserve0
        uint24 lpFee,
        bool zeroForOne
    ) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        PriceMath.getInputToRatio(reserve0, reserve1, liquidity, priceTarget, lpFee, zeroForOne);
        return gasBefore - gasleft();
    }
}
