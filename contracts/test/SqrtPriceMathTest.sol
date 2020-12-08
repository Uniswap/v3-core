// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '../libraries/SqrtPriceMath.sol';
import '../libraries/FixedPoint64.sol';

contract SqrtPriceMathTest {
    function getNextPrice(
        FixedPoint64.uq64x64 memory sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external pure returns (FixedPoint64.uq64x64 memory sqrtQ) {
        return SqrtPriceMath.getNextPrice(sqrtP, liquidity, amountIn, zeroForOne);
    }

    function getGasCostOfGetNextPrice(
        FixedPoint64.uq64x64 memory sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SqrtPriceMath.getNextPrice(sqrtP, liquidity, amountIn, zeroForOne);
        return gasBefore - gasleft();
    }

    function getAmount0Delta(
        FixedPoint64.uq64x64 memory sqrtP,
        FixedPoint64.uq64x64 memory sqrtQ,
        uint128 liquidity,
        bool roundUp
    ) external pure returns (uint256 amount0) {
        return SqrtPriceMath.getAmount0Delta(sqrtP, sqrtQ, liquidity, roundUp);
    }

    function getAmount1Delta(
        FixedPoint64.uq64x64 memory sqrtP,
        FixedPoint64.uq64x64 memory sqrtQ,
        uint128 liquidity,
        bool roundUp
    ) external pure returns (uint256 amount1) {
        return SqrtPriceMath.getAmount1Delta(sqrtP, sqrtQ, liquidity, roundUp);
    }

    function getGasCostOfGetAmount0Delta(
        FixedPoint64.uq64x64 memory sqrtP,
        FixedPoint64.uq64x64 memory sqrtQ,
        uint128 liquidity,
        bool roundUp
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SqrtPriceMath.getAmount0Delta(sqrtP, sqrtQ, liquidity, roundUp);
        return gasBefore - gasleft();
    }

    function getGasCostOfGetAmount1Delta(
        FixedPoint64.uq64x64 memory sqrtP,
        FixedPoint64.uq64x64 memory sqrtQ,
        uint128 liquidity,
        bool roundUp
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SqrtPriceMath.getAmount1Delta(sqrtP, sqrtQ, liquidity, roundUp);
        return gasBefore - gasleft();
    }
}
