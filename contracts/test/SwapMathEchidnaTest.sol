// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/Babylonian.sol';

import '../libraries/FixedPoint128.sol';
import '../libraries/TickMath.sol';
import '../libraries/SwapMath.sol';

contract SwapMathEchidnaTest {
    function requirePriceWithinBounds(uint256 price) private pure {
        require(price < TickMath.getRatioAtTick(TickMath.MAX_TICK));
        require(price >= TickMath.getRatioAtTick(TickMath.MIN_TICK));
    }

    function checkComputeSwapStepInvariants(
        uint256 priceRaw,
        uint256 priceTargetRaw,
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
            FixedPoint128.uq128x128 memory priceAfter,
            uint256 amountIn, /*uint256 amountOut*/
            ,
            uint256 feeAmount
        ) = SwapMath.computeSwapStep(
            FixedPoint128.uq128x128(priceRaw),
            FixedPoint128.uq128x128(priceTargetRaw),
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
