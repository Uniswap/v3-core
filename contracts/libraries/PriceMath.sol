// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

library PriceMath {
    using FixedPoint for FixedPoint.uq112x112;

    uint16 public constant LP_FEE_BASE = 1e4; // i.e. 10k bips, 100%

    function getInputToRatio(
        uint112 reserveIn,
        uint112 reserveOut,
        uint16 lpFee,
        FixedPoint.uq112x112 memory inOutRatio
    ) internal pure returns (uint112 amountIn) {
        FixedPoint.uq112x112 memory reserveRatio = FixedPoint.fraction(reserveIn, reserveOut);
        if (reserveRatio._x >= inOutRatio._x) return 0; // short-circuit if the ratios are equal

        uint256 inputToRatio = getInputToRatioUQ128x128(reserveIn, reserveOut, lpFee, inOutRatio._x);
        require(inputToRatio >> 112 <= type(uint112).max, 'PriceMath: TODO');
        return uint112(inputToRatio >> 112);
    }

    /**
     * Calculate (y(g - 2) + sqrt (g^2 * y^2 + 4xyr(1 - g))) / 2(1 - g) * 2^112, where
     * y = reserveIn,
     * x = reserveOut,
     * g = lpFee * 10^-6,
     * r = inOutRatio * 2^-112.
     * Throw on overflow.
     */
    function getInputToRatioUQ128x128(
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
