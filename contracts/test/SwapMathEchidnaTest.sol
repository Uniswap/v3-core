// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/Babylonian.sol';

import '../libraries/FixedPoint128.sol';
import '../libraries/TickMath.sol';
import '../libraries/SwapMath.sol';

contract SwapMathEchidnaTest {
    function requirePriceWithinBounds(uint128 price) private pure {
        require(price < TickMath.getRatioAtTick(TickMath.MAX_TICK / 2));
        require(price >= TickMath.getRatioAtTick(TickMath.MIN_TICK / 2));
    }

    function checkComputeSwapStepInvariants(
        uint128 priceRaw,
        uint128 priceTargetRaw,
        uint128 liquidity,
        uint256 amountInMax,
        uint24 feePips
    ) external pure {
        requirePriceWithinBounds(priceRaw);
        requirePriceWithinBounds(priceTargetRaw);
        require(feePips < 1e6);

        bool zeroForOne = priceRaw >= priceTargetRaw;

        require(amountInMax > 0);

        (
            FixedPoint64.uq64x64 memory priceAfter,
            uint256 amountIn, /*uint256 amountOut*/
            ,
            uint256 feeAmount
        ) = SwapMath.computeSwapStep(
            FixedPoint64.uq64x64(priceRaw),
            FixedPoint64.uq64x64(priceTargetRaw),
            liquidity,
            amountInMax,
            feePips,
            zeroForOne
        );

        if (zeroForOne) {
            assert(Babylonian.sqrt(priceAfter._x) <= Babylonian.sqrt(priceRaw));
            assert(Babylonian.sqrt(priceAfter._x) >= Babylonian.sqrt(priceTargetRaw));
        } else {
            assert(Babylonian.sqrt(priceAfter._x) >= Babylonian.sqrt(priceRaw));
            assert(Babylonian.sqrt(priceAfter._x) <= Babylonian.sqrt(priceTargetRaw));
        }

        assert(amountIn + feeAmount <= amountInMax);
    }
}
