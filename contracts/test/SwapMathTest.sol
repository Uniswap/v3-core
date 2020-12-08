// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '../libraries/SwapMath.sol';
import '../libraries/FixedPoint64.sol';

contract SwapMathTest {
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
        return SwapMath.computeSwap(price, target, liquidity, amountInMax, feePips, zeroForOne);
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
        SwapMath.computeSwap(price, target, liquidity, amountInMax, feePips, zeroForOne);
        return gasBefore - gasleft();
    }
}
