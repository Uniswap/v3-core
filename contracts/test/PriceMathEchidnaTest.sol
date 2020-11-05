// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '../libraries/PriceMath.sol';
import '../libraries/TickMath.sol';

contract PriceMathEchidnaTest {
    using SafeMath for uint256;

    function getAmountOutInvariants(
        uint112 reserveIn,
        uint112 reserveOut,
        uint112 amountIn
    ) external pure {
        require(reserveIn > 0 && reserveOut > 0);

        uint112 amountOut = PriceMath.getAmountOut(reserveIn, reserveOut, amountIn);
        assert(amountOut < reserveOut);

        uint256 k = uint256(reserveIn).mul(reserveOut);
        uint256 reserveInAfter = uint256(reserveIn).add(amountIn);
        uint256 reserveOutAfter = uint256(reserveOut).sub(amountOut);
        uint256 kAfter = reserveInAfter.mul(reserveOutAfter);
        assert(kAfter >= k);
    }

    function getInputToRatioInvariants(
        uint112 reserve0,
        uint112 reserve1,
        uint16 lpFee,
        int16 tick,
        bool zeroForOne
    ) external pure {
        // UniswapV3Pair.TOKEN_MIN
        require(reserve0 >= 101 && reserve1 >= 101);
        require(lpFee < PriceMath.LP_FEE_BASE);
        require(tick >= TickMath.MIN_TICK && tick < TickMath.MAX_TICK);
        FixedPoint.uq112x112 memory priceTarget = TickMath.getRatioAtTick(tick);

        FixedPoint.uq112x112 memory priceBefore = FixedPoint.fraction(reserve1, reserve0);

        //        // the target next price is within 10%
        //        // TODO can we remove this?
        //        if (zeroForOne) require(priceBefore.mul(90).div(100) <= priceTarget._x);
        //        else require(priceBefore.mul(110).div(100) >= priceTarget._x);

        uint112 amountIn = PriceMath.getInputToRatio(reserve0, reserve1, lpFee, priceTarget, zeroForOne);

        if (amountIn == 0) {
            // amountIn should only be 0 if the current price gte the inOutRatio
            if (zeroForOne) assert(priceBefore._x <= priceTarget._x);
            else assert(priceBefore._x >= priceTarget._x);
        } else {
            uint112 effectiveAmountIn = uint112(
                (uint256(amountIn) * (PriceMath.LP_FEE_BASE - lpFee)) / PriceMath.LP_FEE_BASE
            );
            uint112 amountOut = zeroForOne
                ? PriceMath.getAmountOut(reserve0, reserve1, effectiveAmountIn)
                : PriceMath.getAmountOut(reserve1, reserve0, effectiveAmountIn);

            (uint112 reserve0Next, uint112 reserve1Next) = zeroForOne
                ? (reserve0 + effectiveAmountIn, reserve1 - amountOut)
                : (reserve0 - amountOut, reserve1 + effectiveAmountIn);

            FixedPoint.uq112x112 memory priceAfterSwap = FixedPoint.fraction(reserve1Next, reserve0Next);

            // check:
            //  - the price does not exceed the next price
            //  - todo: one more wei of effective amount in would result in a price that exceeds the next price
            if (zeroForOne) {
                assert(priceAfterSwap._x > priceTarget._x);
            } else {
                assert(priceAfterSwap._x < priceTarget._x);
            }
        }
    }
}
