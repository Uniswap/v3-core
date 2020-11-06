// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import '../libraries/PriceMath.sol';

contract PriceMathTest {
    function getInputToRatio(
        uint112 reserve0,
        uint112 reserve1,
        uint16 lpFee,
        FixedPoint.uq112x112 memory priceTarget,
        bool zeroForOne
    ) public pure returns (uint112 amountIn, uint112 amountOut) {
        return PriceMath.getInputToRatio(reserve0, reserve1, lpFee, priceTarget, zeroForOne);
    }

    function getAmountOut(
        uint112 reserveIn,
        uint112 reserveOut,
        uint112 amountIn
    ) external pure returns (uint112) {
        return PriceMath.getAmountOut(reserveIn, reserveOut, amountIn);
    }

    function getGasCostOfGetInputToRatio(
        uint112 reserve0,
        uint112 reserve1,
        uint16 lpFee,
        FixedPoint.uq112x112 memory priceTarget,
        bool zeroForOne
    ) public view returns (uint256) {
        uint256 gasBefore = gasleft();
        PriceMath.getInputToRatio(reserve0, reserve1, lpFee, priceTarget, zeroForOne);
        return gasBefore - gasleft();
    }
}
