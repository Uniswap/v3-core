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
        require(uint(tick < 0 ? -tick : tick) < uint(TickMath.MAX_TICK));
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
        }

        // PriceMath.getAmountOut
        uint256 amountOut = ((uint256(reserveOut) * amountIn * (PriceMath.LP_FEE_BASE - lpFee)) /
            (uint256(amountIn) * (PriceMath.LP_FEE_BASE - lpFee) + uint256(reserveIn) * PriceMath.LP_FEE_BASE));

        // TODO work on these
        // assert(amountOut > 0);
        // if (amountOut >= reserveOut) amountOut = reserveOut - 1;

        uint256 reserveOutAfter = uint256(reserveOut).sub(amountOut);
        uint256 reserveInAfter = uint256(reserveIn).add(amountIn);
        // TODO these should be uint112(-1)
        assert(reserveOutAfter <= uint144(-1));
        assert(reserveInAfter <= uint144(-1));
        uint256 priceAfter = zeroForOne
            ? (reserveOutAfter << 112) / reserveInAfter
            : (reserveInAfter << 112) / reserveOutAfter;

        // if (zeroForOne) assert(priceAfter <= nextPrice._x);
        // else assert(priceAfter >= nextPrice._x);
    }
}
