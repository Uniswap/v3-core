// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '../libraries/PriceMath.sol';
import '../libraries/TickMath.sol';

contract PriceMathEchidnaTest {
    using SafeMath for uint256;

    function getAmountOutInvariants(
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 amountIn
    ) external pure {
        require(reserveIn > 0 && reserveOut > 0);

        uint256 amountOut = PriceMath.getAmountOut(reserveIn, reserveOut, amountIn);
        assert(amountOut < reserveOut);

        uint256 k = reserveIn.mul(reserveOut);
        uint256 reserveInAfter = reserveIn.add(amountIn);
        uint256 reserveOutAfter = reserveOut.sub(amountOut);
        uint256 kAfter = reserveInAfter.mul(reserveOutAfter);
        assert(kAfter >= k);
    }

    function roundingCanBeGreaterThan1(uint224 price, uint112 liquidity) external pure {
        require(price >= TickMath.getRatioAtTick(TickMath.MIN_TICK)._x);
        require(price <= TickMath.getRatioAtTick(TickMath.MAX_TICK)._x);

        (uint256 amount0Up, uint256 amount1Up) = PriceMath.getVirtualReservesAtPrice(
            FixedPoint128.uq128x128(price),
            liquidity,
            true
        );
        (uint256 amount0Down, uint256 amount1Down) = PriceMath.getVirtualReservesAtPrice(
            FixedPoint128.uq128x128(price),
            liquidity,
            false
        );
        assert(amount0Up >= amount0Down);
        assert(amount1Up >= amount1Down);
        assert(amount0Up - amount0Down <= 2);
        assert(amount1Up - amount1Down <= 2);
    }

    function getAmountOutAlwaysLtDifferenceInPrices(
        uint224 priceRaw,
        uint224 priceNextRaw,
        uint112 liquidity
    ) external pure {
        require(priceRaw > 0 && priceNextRaw > 0 && liquidity > 0);
        bool zeroForOne = priceNextRaw <= priceRaw;
        (uint256 reserve0, uint256 reserve1) = PriceMath.getVirtualReservesAtPrice(
            FixedPoint128.uq128x128(priceRaw),
            liquidity,
            false
        );
        (uint256 reserve0Next, uint256 reserve1Next) = PriceMath.getVirtualReservesAtPrice(
            FixedPoint128.uq128x128(priceNextRaw),
            liquidity,
            false
        );
        uint256 amountIn = zeroForOne ? reserve0Next - reserve0 : reserve1Next - reserve1;
        uint256 amountOut = zeroForOne
            ? PriceMath.getAmountOut(reserve0, reserve1, amountIn)
            : PriceMath.getAmountOut(reserve1, reserve0, amountIn);
        uint256 maxAmountOut = zeroForOne ? reserve1 - reserve1Next : reserve0 - reserve0Next;
        assert(amountOut < maxAmountOut);
    }

    function getInputToRatioInvariants(
        uint224 priceRaw,
        int24 tickTarget,
        uint112 liquidity,
        uint24 lpFee
    ) external pure {
        require(tickTarget >= TickMath.MIN_TICK && tickTarget < TickMath.MAX_TICK);
        require(liquidity > 0);
        require(lpFee > 0 && lpFee < PriceMath.LP_FEE_BASE);

        FixedPoint128.uq128x128 memory price = FixedPoint128.uq128x128(priceRaw);
        (uint256 reserve0, uint256 reserve1) = PriceMath.getVirtualReservesAtPrice(price, liquidity, false);

        require(reserve0 > 0 && reserve1 > 0);

        FixedPoint128.uq128x128 memory priceTarget = TickMath.getRatioAtTick(tickTarget);
        bool zeroForOne = price._x >= priceTarget._x;

        (uint256 amountIn, uint256 amountOutMax) = PriceMath.getInputToRatio(
            reserve0,
            reserve1,
            liquidity,
            priceTarget,
            lpFee,
            zeroForOne
        );

        if (amountIn == 0) {
            // amountIn should only be 0 if the current price is past the target price
            if (zeroForOne) assert(price._x <= priceTarget._x);
            else assert(price._x >= priceTarget._x);
            assert(amountOutMax == 0);
        } else {
            assert((zeroForOne ? reserve1 : reserve0) > amountOutMax);

            uint112 amountInLessFee = uint112((amountIn * (PriceMath.LP_FEE_BASE - lpFee)) / PriceMath.LP_FEE_BASE);
            uint256 amountOut = zeroForOne
                ? PriceMath.getAmountOut(reserve0, reserve1, amountInLessFee)
                : PriceMath.getAmountOut(reserve1, reserve0, amountInLessFee);

            // downward-adjust amount out if necessary
            amountOut = Math.min(amountOut, amountOutMax);

            // (uint112 reserve0Next, uint112 reserve1Next) = zeroForOne
            //     ? (reserve0 + amountInLessFee, reserve1 - amountOut)
            //     : (reserve0 - amountOut, reserve1 + amountInLessFee);

            // // check that the price does not exceed the next price
            // {
            //     FixedPoint128.uq128x128 memory priceAfterSwap = FixedPoint.fraction(reserve1Next, reserve0Next);
            //     if (zeroForOne) assert(priceAfterSwap._x >= priceTarget._x);
            //     else assert(priceAfterSwap._x <= priceTarget._x);
            // }

            // (reserve0Next, reserve1Next) = zeroForOne
            //     ? (reserve0 + amountInLessFee + 1, reserve1 - amountOut)
            //     : (reserve0 - amountOut, reserve1 + amountInLessFee + 1);

            // // check that one more wei of amount in would result in a price that exceeds the next price
            // {
            //     FixedPoint128.uq128x128 memory priceAfterSwap1MoreWei = FixedPoint.fraction(reserve1Next, reserve0Next);
            //     if (zeroForOne) assert(priceAfterSwap1MoreWei._x <= priceTarget._x);
            //     else assert(priceAfterSwap1MoreWei._x >= priceTarget._x);
            // }
        }
    }
}
