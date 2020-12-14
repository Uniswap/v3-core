// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '../libraries/SwapMath.sol';
import '../libraries/FixedPoint96.sol';

contract SwapMathTest {
    function computeSwapStep(
        FixedPoint96.uq64x96 memory price,
        FixedPoint96.uq64x96 memory target,
        uint128 liquidity,
        uint256 amountInMax,
        uint24 feePips,
        bool zeroForOne
    )
        external
        pure
        returns (
            FixedPoint96.uq64x96 memory priceAfter,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        return SwapMath.computeSwapStep(price, target, liquidity, amountInMax, feePips, zeroForOne);
    }

    function getGasCostOfComputeSwapStep(
        FixedPoint96.uq64x96 memory price,
        FixedPoint96.uq64x96 memory target,
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
