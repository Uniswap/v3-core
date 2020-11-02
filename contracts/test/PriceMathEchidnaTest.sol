// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '../libraries/PriceMath.sol';
import '../libraries/TickMath.sol';

contract PriceMathEchidnaTest {
    using SafeMath for uint256;

    uint224 MIN_PRICE;
    uint224 MAX_PRICE;

    constructor() public {
        MIN_PRICE = uint224(TickMath.getRatioAtTick(TickMath.MIN_TICK)._x);
        MAX_PRICE = uint224(TickMath.getRatioAtTick(TickMath.MAX_TICK)._x);
    }

    function getAmountOutInvariants(
        uint112 reserveIn,
        uint112 reserveOut,
        uint16 lpFee,
        uint112 amountIn
    ) external pure {
        require(lpFee < PriceMath.LP_FEE_BASE);
        require(reserveIn > 0 && reserveOut > 0);

        uint112 amountOut = PriceMath.getAmountOut(reserveIn, reserveOut, lpFee, amountIn);
        assert(amountOut < reserveOut);

        uint256 k = uint256(reserveIn).mul(reserveOut);
        uint256 fee = uint256(amountIn).mul(lpFee).div(PriceMath.LP_FEE_BASE);
        uint256 reserveInAfter = uint256(reserveIn).add(amountIn).sub(fee);
        uint256 reserveOutAfter = uint256(reserveOut).sub(amountOut);
        uint256 kAfter = reserveInAfter.mul(reserveOutAfter);
        assert(kAfter >= k);
    }

    function getInputToRatioAlwaysExceedsNextPrice(
        uint112 reserveIn,
        uint112 reserveOut,
        uint16 lpFee,
        int16 tick,
        bool zeroForOne
    ) external pure {
        // UniswapV3Pair.TOKEN_MIN
        require(reserveIn >= 101 && reserveOut >= 101);
        require(lpFee < PriceMath.LP_FEE_BASE);
        require(tick >= TickMath.MIN_TICK && tick < TickMath.MAX_TICK);
        FixedPoint.uq112x112 memory nextPrice = zeroForOne
            ? TickMath.getRatioAtTick(tick)
            : TickMath.getRatioAtTick(tick + 1);

        uint256 priceBefore = zeroForOne
            ? (uint256(reserveOut) << 112) / reserveIn
            : (uint256(reserveIn) << 112) / reserveOut;

        // the target next price is within 10%
        // TODO can we remove this?
        if (zeroForOne) require(priceBefore.mul(90).div(100) <= nextPrice._x);
        else require(priceBefore.mul(110).div(100) >= nextPrice._x);

        uint112 amountIn = PriceMath.getInputToRatio(
            reserveIn,
            reserveOut,
            lpFee,
            nextPrice,
            zeroForOne ? TickMath.getRatioAtTick(-tick) : TickMath.getRatioAtTick(-(tick + 1)),
            zeroForOne
        );

        if (amountIn == 0) {
            // amountIn should only be 0 if the current price gte the inOutRatio
            if (zeroForOne) assert(priceBefore <= nextPrice._x);
            else assert(priceBefore >= nextPrice._x);
            return;
        } else {
            uint112 amountOut = PriceMath.getAmountOut(reserveIn, reserveOut, lpFee, amountIn);
            uint112 reserveInNext = reserveIn + amountIn;
            uint112 reserveOutNext = reserveOut - amountOut;
            FixedPoint.uq112x112 memory priceAfterSwap = zeroForOne
                ? FixedPoint.fraction(reserveOutNext, reserveInNext)
                : FixedPoint.fraction(reserveInNext, reserveOutNext);

            if (zeroForOne) assert(priceAfterSwap._x <= nextPrice._x && priceAfterSwap._x > (nextPrice._x * 99) / 100);
            else assert(priceAfterSwap._x >= nextPrice._x && priceAfterSwap._x < (nextPrice._x * 101) / 100);
        }
    }
}
