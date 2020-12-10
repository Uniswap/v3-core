// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '../libraries/SqrtPriceMath.sol';
import '../libraries/FixedPoint64.sol';

contract SqrtPriceMathTest {
    function getNextPriceFromInput(
        FixedPoint64.uq64x64 memory sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external pure returns (FixedPoint64.uq64x64 memory sqrtQ) {
        return SqrtPriceMath.getNextPriceFromInput(sqrtP, liquidity, amountIn, zeroForOne);
    }

    function getGasCostOfGetNextPriceFromInput(
        FixedPoint64.uq64x64 memory sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SqrtPriceMath.getNextPriceFromInput(sqrtP, liquidity, amountIn, zeroForOne);
        return gasBefore - gasleft();
    }

    function getNextPriceFromOutput(
        FixedPoint64.uq64x64 memory sqrtP,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) external pure returns (FixedPoint64.uq64x64 memory sqrtQ) {
        return SqrtPriceMath.getNextPriceFromOutput(sqrtP, liquidity, amountOut, zeroForOne);
    }

    function getGasCostOfGetNextPriceFromOutput(
        FixedPoint64.uq64x64 memory sqrtP,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SqrtPriceMath.getNextPriceFromOutput(sqrtP, liquidity, amountOut, zeroForOne);
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
