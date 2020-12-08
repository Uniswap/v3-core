// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

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
        uint24 feePips,
        bool zeroForOne
    ) external pure {
        requirePriceWithinBounds(priceRaw);
        requirePriceWithinBounds(priceTargetRaw);
        require(feePips < 1e6);

        if (zeroForOne) {
            if (priceRaw < priceTargetRaw) {
                (priceTargetRaw, priceRaw) = (priceRaw, priceTargetRaw);
            }
        } else {
            if (priceRaw > priceTargetRaw) {
                (priceTargetRaw, priceRaw) = (priceRaw, priceTargetRaw);
            }
        }

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
            assert(priceAfter._x <= priceRaw);
            assert(priceAfter._x >= priceTargetRaw);
        } else {
            assert(priceAfter._x >= priceRaw);
            assert(priceAfter._x <= priceTargetRaw);
        }

        assert(amountIn + feeAmount <= amountInMax);
    }
}
