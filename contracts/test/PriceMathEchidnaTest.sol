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
        uint112 reserve0,
        uint112 reserve1,
        uint16 lpFee,
        int16 tick,
        bool zeroForOne
    ) external pure {
        // UniswapV3Pair.TOKEN_MIN
        require(reserve0 >= 101 && reserve1 >= 101);
        require(lpFee < PriceMath.LP_FEE_BASE);
        require(uint(tick < 0 ? -tick : tick) < uint(TickMath.MAX_TICK));
        FixedPoint.uq112x112 memory nextPrice = zeroForOne
            ? TickMath.getRatioAtTick(tick)
            : TickMath.getRatioAtTick(tick + 1);

        uint256 priceBefore = (uint256(reserve1) << 112) / reserve0;

        // the target next price is within 10%
        // TODO can we remove this?
        if (zeroForOne) require(priceBefore.mul(90).div(100) <= nextPrice._x);
        else require(priceBefore.mul(110).div(100) >= nextPrice._x);

        uint112 amountIn = PriceMath.getInputToRatio(
            reserve0,
            reserve1,
            lpFee,
            nextPrice,
            zeroForOne
        );

        if (amountIn == 0) {
            // amountIn should only be 0 if the current price gte the inOutRatio
            if (zeroForOne) assert(priceBefore <= nextPrice._x);
            else assert(priceBefore >= nextPrice._x);
            return;
        }
    }
}
