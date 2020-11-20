// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.4.0;

import '@uniswap/lib/contracts/libraries/FullMath.sol';

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
library FixedPoint128 {
    // range: [0, 2*128 - 1]
    // resolution: 1 / 2**128
    struct uq128x128 {
        uint256 _x;
    }

    uint8 private constant RESOLUTION = 128;
    uint256 private constant Q128 = 0x100000000000000000000000000000000;
    uint256 private constant LOWER_MASK = 0xffffffffffffffffffffffffffffff; // decimal of UQ*x128 (lower 128 bits)

    // encode a uint112 as a uq128x128
    function encode(uint128 x) internal pure returns (uq128x128 memory) {
        return uq128x128(uint224(x) << RESOLUTION);
    }

    // decode a uq128x128 into a uint112 by truncating after the radix point
    function decode(uq128x128 memory self) internal pure returns (uint112) {
        return uint112(self._x >> RESOLUTION);
    }

    // returns a uq128x128 which represents the ratio of the numerator to the denominator
    function fraction(uint256 numerator, uint256 denominator) internal pure returns (uq128x128 memory) {
        require(denominator > 0, 'FixedPoint128::fraction: division by zero');
        if (numerator == 0) return uq128x128(0);

        if (numerator <= uint128(-1)) {
            uint256 result = (numerator << RESOLUTION) / denominator;
            return uq128x128(result);
        } else {
            return uq128x128(FullMath.mulDiv(numerator, Q128, denominator));
        }
    }
}
