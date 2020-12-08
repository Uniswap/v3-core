// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

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
            assert(priceAfter._x <= priceRaw);
            assert(priceAfter._x >= priceTargetRaw);
        } else {
            assert(priceAfter._x >= priceRaw);
            assert(priceAfter._x <= priceTargetRaw);
        }

        assert(amountIn + feeAmount <= amountInMax);
    }
}
