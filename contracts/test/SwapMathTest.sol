// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '../libraries/SwapMath.sol';
import '../libraries/FixedPoint64.sol';

contract SwapMathTest {
    function computeSwapStep(
        FixedPoint64.uq64x64 memory price,
        FixedPoint64.uq64x64 memory target,
        uint128 liquidity,
        uint256 amountInMax,
        uint24 feePips,
        bool zeroForOne
    )
        external
        pure
        returns (
            FixedPoint64.uq64x64 memory priceAfter,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        return SwapMath.computeSwapStep(price, target, liquidity, amountInMax, feePips, zeroForOne);
    }

    function getGasCostOfComputeSwapStep(
        FixedPoint64.uq64x64 memory price,
        FixedPoint64.uq64x64 memory target,
        uint128 liquidity,
        uint256 amountInMax,
        uint24 feePips,
        bool zeroForOne
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        SwapMath.computeSwapStep(price, target, liquidity, amountInMax, feePips, zeroForOne);
        return gasBefore - gasleft();
    }
}
