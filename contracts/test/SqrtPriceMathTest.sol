// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/SqrtPriceMath.sol';

contract SqrtPriceMathTest {
    function getNextPriceFromInput(
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external pure returns (uint160 sqrtQ) {
        return SqrtPriceMath.getNextPriceFromInput(sqrtP, liquidity, amountIn, zeroForOne);
    }

    function getGasCostOfGetNextPriceFromInput(
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SqrtPriceMath.getNextPriceFromInput(sqrtP, liquidity, amountIn, zeroForOne);
        return gasBefore - gasleft();
    }

    function getNextPriceFromOutput(
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) external pure returns (uint160 sqrtQ) {
        return SqrtPriceMath.getNextPriceFromOutput(sqrtP, liquidity, amountOut, zeroForOne);
    }

    function getGasCostOfGetNextPriceFromOutput(
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SqrtPriceMath.getNextPriceFromOutput(sqrtP, liquidity, amountOut, zeroForOne);
        return gasBefore - gasleft();
    }

    function getAmount0Delta(
        uint160 sqrtP,
        uint160 sqrtQ,
        uint128 liquidity,
        bool roundUp
    ) external pure returns (uint256 amount0) {
        return SqrtPriceMath.getAmount0Delta(sqrtP, sqrtQ, liquidity, roundUp);
    }

    function getAmount1Delta(
        uint160 sqrtP,
        uint160 sqrtQ,
        uint128 liquidity,
        bool roundUp
    ) external pure returns (uint256 amount1) {
        return SqrtPriceMath.getAmount1Delta(sqrtP, sqrtQ, liquidity, roundUp);
    }

    function getGasCostOfGetAmount0Delta(
        uint160 sqrtP,
        uint160 sqrtQ,
        uint128 liquidity,
        bool roundUp
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SqrtPriceMath.getAmount0Delta(sqrtP, sqrtQ, liquidity, roundUp);
        return gasBefore - gasleft();
    }

    function getGasCostOfGetAmount1Delta(
        uint160 sqrtP,
        uint160 sqrtQ,
        uint128 liquidity,
        bool roundUp
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SqrtPriceMath.getAmount1Delta(sqrtP, sqrtQ, liquidity, roundUp);
        return gasBefore - gasleft();
    }
}
