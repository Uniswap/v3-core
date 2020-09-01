// SPDX-License-Identifier: GPL-3.0-or-later
/*
 * Author: Mikhail Vladimirov <mikhail.vladimirov@gmail.com>
 */
pragma solidity ^0.5.0 || ^0.6.0;

/**
 * Swap contract library implementing utility functions for Uniswap Math model.
 */
library UniswapMath {
    /**
     * Calculate 1.01^tick * 2^128.  Throw in case |tick| > 7802.
     */
    function getRatioAtTick (int256 tick)
    internal pure returns (uint256 ratio) {
        uint256 absTick = uint256 (tick >= 0 ? tick : -tick);
        require (absTick <= 7802);

        ratio = absTick & 0x1 != 0 ? 0xfd7720f353a4c0a237c32b16cfd7720f : 0x100000000000000000000000000000000;
        if (absTick & 0x2 != 0) ratio = ratio * 0xfaf4ae9099c9241ccf4a1b745e424d72 >> 128;
        if (absTick & 0x4 != 0) ratio = ratio * 0xf602cecfa70ae4afe789b849b8ba756d >> 128;
        if (absTick & 0x8 != 0) ratio = ratio * 0xec69657ef75a64f2bc647042cf997b9b >> 128;
        if (absTick & 0x10 != 0) ratio = ratio * 0xda527e868273006c1a1a2faf830951f8 >> 128;
        if (absTick & 0x20 != 0) ratio = ratio * 0xba309a1262e01d7a68fd2cf1bd98bbe8 >> 128;
        if (absTick & 0x40 != 0) ratio = ratio * 0x876aa91cdb4cdf289fa30a8cd1d4bc37 >> 128;
        if (absTick & 0x80 != 0) ratio = ratio * 0x47a1aacceae7cbd1d95338b2354be7f2 >> 128;
        if (absTick & 0x100 != 0) ratio = ratio * 0x140b12d5f200d69fd82ba1b225ef0175 >> 128;
        if (absTick & 0x200 != 0) ratio = ratio * 0x191bb6c0d95b67023dc9b2e7f36d979 >> 128;
        if (absTick & 0x400 != 0) ratio = ratio * 0x2766cb1b99879bae2a835f8b53197 >> 128;
        if (absTick & 0x800 != 0) ratio = ratio * 0x6107b28e3ea71f5ef5255e1a7 >> 128;
        if (absTick & 0x1000 != 0) ratio = ratio * 0x24c6d58b0bcc3113a5 >> 128;

        if (tick > 0) ratio = uint256 (-1) / ratio;
    }

    /**
     * Calculate (y(g - 2) + sqrt (g^2 * y^2 + 4xyr(1 - g))) / 2(1 - g) * 2^112, where
     * y = reserveIn,
     * x = reserveOut,
     * g = lpFee * 10^-6,
     * r = inOutRatio * 2^-112.
     * Throw on overflow.
     */
    function getInputToRatio (
        uint112 reserveIn, uint112 reserveOut,
        uint16 lpFee, uint224 inOutRatio)
    internal pure returns (uint256 amountIn) {
        // g2y2 = g^2 * y^2 * 1e6 (max value: ~2^236)
        uint256 g2y2 = (uint256 (lpFee) * uint256 (lpFee) * uint256 (reserveIn) * uint256 (reserveIn) + 999999) / 1e6;

        // xyr4g1 = 4 * x * y * (1 - g) * 1e6 (max value: ~2^246)
        uint256 xy41g = 4 * uint256 (reserveIn) * uint256 (reserveOut) * (1e6 - uint256 (lpFee));

        // xyr41g = 4 * x * y * r * (1 - g) * 1e6 (max value: ~2^246)
        uint256 xyr41g = mulshift (xy41g, uint256 (inOutRatio), 112);
        require (xyr41g < 2**254);

        // sr = sqrt (g^2 * y^2 + 4 * x * y * r * (1 - g)) * 2^128
        uint256 sr = (sqrt (g2y2 + xyr41g) + 999) / 1000;

        // y2g = y(2 - g) * 2^128
        uint256 y2g = uint256 (reserveIn) * (2e6 - uint256 (lpFee)) * 0x10c6f7a0b5ed8d36b4c7f3493858;

        // Make sure numerator is non-negative
        require (sr >= y2g);

        // num = (sqrt (g^2 * y^2 + 4 * x * y * r * (1 - g)) - y(2 - g)) * 2^128
        uint256 num = sr - y2g;

        // den = 2 * (1 - g) * 1e6
        uint256 den = 2 * (1e6 - uint256 (lpFee));

        return ((num + den - 1) / den * 1e6 + 0xffff) >> 16;
    }

    /**
     * Calculate x * y >> s rounding up.  Throw on overflow.
     */
    function mulshift (uint256 x, uint256 y, uint8 s)
    internal pure returns (uint256 result) {
        uint256 l = x * y;
        uint256 m = mulmod (x, y, uint256 (-1));
        uint256 h = m - l;
        if (m < l) h -= 1;

        uint256 ss = 256 - s;

        require (h >> s == 0);
        result = (h << ss) | (l >> s);
        if (l << ss > 0) {
            require (result < uint256 (-1));
            result += 1;
        }
    }

    /**
     * Calculate sqrt (x) * 2^128 rounding up.  Throw on overflow.
     */
    function sqrt (uint256 x)
    internal pure returns (uint256 result) {
        if (x == 0) return 0;
        else {
            uint256 s = 128;

            if (x < 2**128) { x <<= 128; s -= 64; }
            if (x < 2**192) { x <<= 64; s -= 32; }
            if (x < 2**224) { x <<= 32; s -= 16; }
            if (x < 2**240) { x <<= 16; s -= 8; }
            if (x < 2**248) { x <<= 8; s -= 4; }
            if (x < 2**252) { x <<= 4; s -= 2; }
            if (x < 2**254) { x <<= 2; s -= 1; }

            result = 2**127;
            result = x / result + result >> 1;
            result = x / result + result >> 1;
            result = x / result + result >> 1;
            result = x / result + result >> 1;
            result = x / result + result >> 1;
            result = x / result + result >> 1;
            result = x / result + result >> 1; // 7 iterations should be enough

            if (result * result < x) result = x / result + 1;

            require (result <= uint256 (-1) >> s);
            result <<= s;
        }
    }
}
