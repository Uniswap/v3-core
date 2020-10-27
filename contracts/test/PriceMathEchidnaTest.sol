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
        uint224 inOutRatio
    ) external view {
        // UniswapV3Pair.TOKEN_MIN
        require(reserveIn >= 101 && reserveOut >= 101);
        require(lpFee < PriceMath.LP_FEE_BASE);
        require(inOutRatio >= MIN_PRICE && inOutRatio <= MAX_PRICE);

        uint256 priceBefore = (uint256(reserveIn) << 112) / reserveOut;

        uint112 amountIn = PriceMath.getInputToRatio(reserveIn, reserveOut, lpFee, FixedPoint.uq112x112(inOutRatio));

        if (amountIn == 0) {
            // amountIn should only be 0 if the current price gte the inOutRatio
            assert(priceBefore >= inOutRatio);
            return;
        }

        // the target next price is within 10%
        // todo: can we remove this?
        require(priceBefore.mul(110).div(100) >= inOutRatio);

        uint256 amountOut = ((uint256(reserveOut) * amountIn * (PriceMath.LP_FEE_BASE - lpFee)) /
            (uint256(amountIn) * (PriceMath.LP_FEE_BASE - lpFee) + uint256(reserveIn) * PriceMath.LP_FEE_BASE));

        assert(amountOut > 0 && amountOut < reserveOut);

        uint256 reserveOutAfter = uint256(reserveOut).sub(amountOut);

        assert(((uint256(reserveIn).add(amountIn)) << 112) / reserveOutAfter >= inOutRatio);
    }
}
