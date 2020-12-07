// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '../libraries/SqrtPriceMath.sol';

contract SqrtPriceMathTest {
    function getPriceAfterSwap(
        uint128 sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external pure returns (uint128 sqrtQ) {
        return SqrtPriceMath.getPriceAfterSwap(sqrtP, liquidity, amountIn, zeroForOne);
    }

    function getGasCostOfGetPriceAfterSwap(
        uint128 sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SqrtPriceMath.getPriceAfterSwap(sqrtP, liquidity, amountIn, zeroForOne);
        return gasBefore - gasleft();
    }

    function getAmountDeltas(
        uint128 sqrtP,
        uint128 sqrtQ,
        uint128 liquidity
    ) external pure returns (int256 amount0, int256 amount1) {
        return SqrtPriceMath.getAmountDeltas(sqrtP, sqrtQ, liquidity);
    }

    function getGasCostOfGetAmountDeltas(
        uint128 sqrtP,
        uint128 sqrtQ,
        uint128 liquidity
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SqrtPriceMath.getAmountDeltas(sqrtP, sqrtQ, liquidity);
        return gasBefore - gasleft();
    }

    function computeSwap(
        FixedPoint128.uq128x128 memory price,
        FixedPoint128.uq128x128 memory target,
        uint128 liquidity,
        uint256 amountInMax,
        uint24 feePips,
        bool zeroForOne
    )
        external
        pure
        returns (
            FixedPoint128.uq128x128 memory priceAfter,
            uint256 amountIn,
            uint256 amountOut
        )
    {
        return SqrtPriceMath.computeSwap(price, target, liquidity, amountInMax, feePips, zeroForOne);
    }

    function getGasCostOfComputeSwap(
        FixedPoint128.uq128x128 memory price,
        FixedPoint128.uq128x128 memory target,
        uint128 liquidity,
        uint256 amountInMax,
        uint24 feePips,
        bool zeroForOne
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SqrtPriceMath.computeSwap(price, target, liquidity, amountInMax, feePips, zeroForOne);
        return gasBefore - gasleft();
    }
}
