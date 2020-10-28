// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/FullMath.sol';

import './SafeCast.sol';

library PriceMath {
    using SafeMath for *;
    using FixedPoint for FixedPoint.uq112x112;
    using SafeCast for *;

    uint16 public constant LP_FEE_BASE = 1e4; // i.e. 10k bips, 100%
    // 2^112 - 1
    // added to the input amount before truncating so that we always round up the amountIn returned by
    // getInputToRatio
    uint256 private constant ROUND_UP = 0xffffffffffffffffffffffffffff;

    // get an amount quote at a price, rounded up
    function getQuote(uint112 amount, FixedPoint.uq112x112 memory ratio) internal pure returns (uint256) {
        return FullMath.mulDiv(amount, ratio._x, uint256(1) << 112, true);
    }

    // get an amount quote at a price (inverted), rounded up
    function getQuoteInverse(uint144 amount, FixedPoint.uq112x112 memory ratio) internal pure returns (uint256) {
        uint256 mm = mulmod(amount, uint256(1) << 112, ratio._x);
        return ((uint256(amount) << 112) / ratio._x) + (mm > 0 ? 1 : 0);
    }

    function getAmountOut(
        uint112 reserveIn,
        uint112 reserveOut,
        uint16 lpFee,
        uint112 amountIn
    ) internal pure returns (uint112) {
        return
            ((uint256(reserveOut) * amountIn * (LP_FEE_BASE - lpFee)) /
                (uint256(amountIn) * (LP_FEE_BASE - lpFee) + uint256(reserveIn) * LP_FEE_BASE))
                .toUint112();
    }

    function getInputToRatio(
        uint112 reserveIn,
        uint112 reserveOut,
        uint16 lpFee,
        FixedPoint.uq112x112 memory nextPrice,        // 1 / 0
        FixedPoint.uq112x112 memory nextPriceInverse, // 0 / 1
        bool zeroForOne
    ) internal pure returns (uint112 amountIn) {
        FixedPoint.uq112x112 memory reservePrice; // 1 / 0
        if (zeroForOne) {
            reservePrice = FixedPoint.fraction(reserveOut, reserveIn);
            if (reservePrice._x <= nextPrice._x) return 0;
        } else {
            reservePrice = FixedPoint.fraction(reserveIn, reserveOut);
            if (reservePrice._x >= nextPrice._x) return 0;
        }

        uint256 inputToRatio = getInputToRatioUQ144x112(
            reserveIn, reserveOut, lpFee, zeroForOne ? nextPriceInverse._x : nextPrice._x
        );
        amountIn = (inputToRatio.add(ROUND_UP) >> 112).toUint112();

        // get the output amount that the input amount entitles the swapper to
        uint256 amountOut = getAmountOut(reserveIn, reserveOut, lpFee, amountIn);

        // if necessary, increase the input amount s.t. we're guaranteed to have crossed the target price
        // TODO do we need to do something along the lines of minning amountOut with reserveOut - 1 here?
        uint112 reserveOutNext = reserveOut.sub(amountOut).toUint112();
        uint256 reserveInThreshold = zeroForOne
            ? getQuoteInverse(reserveOutNext, nextPrice)
            : getQuote(reserveOutNext, nextPrice);
        amountIn = Math.max(amountIn, reserveInThreshold.sub(reserveIn)).toUint112();
    }

    /**
     * Calculate (y(g - 2) + sqrt (g^2 * y^2 + 4xyr(1 - g))) / 2(1 - g) * 2^112, where
     * y = reserveIn,
     * x = reserveOut,
     * g = lpFee * 10^-4,
     * r = inOutRatio * 2^-112.
     * Throw on overflow.
     */
    function getInputToRatioUQ144x112(
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 lpFee,
        uint256 inOutRatio
    ) private pure returns (uint256 amountIn) {
        // g2y2 = g^2 * y^2 * 1e6 (max value: ~2^236)
        uint256 g2y2 = (lpFee * lpFee * uint256(reserveIn) * uint256(reserveIn) + (9999)) / 1e4;

        // xyr4g1 = 4 * x * y * (1 - g) * 1e6 (max value: ~2^246)
        uint256 xy41g = 4 * uint256(reserveIn) * uint256(reserveOut) * (1e4 - lpFee);

        // xyr41g = 4 * x * y * r * (1 - g) * 1e6 (max value: ~2^246)
        uint256 xyr41g = mulshift(xy41g, uint256(inOutRatio));
        require(xyr41g < 2**254);

        // sr = sqrt (g^2 * y^2 + 4 * x * y * r * (1 - g)) * 2^128
        uint256 sr = (sqrt(g2y2 + xyr41g) + 99) / 100;

        // y2g = y(2 - g) * 2^128
        uint256 y2g = uint256(reserveIn) * ((2e4) - lpFee) * 0x68db8bac710cb295e9e1b089a0275;

        // Make sure numerator is non-negative
        require(sr >= y2g);

        // num = (sqrt (g^2 * y^2 + 4 * x * y * r * (1 - g)) - y(2 - g)) * 2^128
        uint256 num = sr - y2g;

        // den = 2 * (1 - g) * 1e6
        uint256 den = 2 * (1e4 - lpFee);

        return (((num + den - 1) / den) * 1e4 + 0xffff) >> 16;
    }

    /**
     * Calculate x * y >> 112 rounding up.  Throw on overflow.
     */
    function mulshift(uint256 x, uint256 y) private pure returns (uint256 result) {
        uint256 l = x * y;
        uint256 m = mulmod(x, y, uint256(-1));
        uint256 h = m - l;
        if (m < l) h -= 1;

        require(h >> 112 == 0);
        result = (h << 144) | (l >> 112);
        if (l << 112 > 0) {
            require(result < uint256(-1));
            result += 1;
        }
    }

    /**
     * Calculate sqrt (x) * 2^128 rounding up.  Throw on overflow.
     */
    function sqrt(uint256 x) private pure returns (uint256 result) {
        if (x == 0) return 0;
        else {
            uint256 s = 128;

            if (x < 2**128) {
                x <<= 128;
                s -= 64;
            }
            if (x < 2**192) {
                x <<= 64;
                s -= 32;
            }
            if (x < 2**224) {
                x <<= 32;
                s -= 16;
            }
            if (x < 2**240) {
                x <<= 16;
                s -= 8;
            }
            if (x < 2**248) {
                x <<= 8;
                s -= 4;
            }
            if (x < 2**252) {
                x <<= 4;
                s -= 2;
            }
            if (x < 2**254) {
                x <<= 2;
                s -= 1;
            }

            result = 2**127;
            result = (x / result + result) >> 1;
            result = (x / result + result) >> 1;
            result = (x / result + result) >> 1;
            result = (x / result + result) >> 1;
            result = (x / result + result) >> 1;
            result = (x / result + result) >> 1;
            result = (x / result + result) >> 1; // 7 iterations should be enough

            if (result * result < x) result = x / result + 1;

            require(result <= uint256(-1) >> s);
            result <<= s;
        }
    }
}
