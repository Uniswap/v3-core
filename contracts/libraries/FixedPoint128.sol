// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.0;

import './FullMath.sol';

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
library FixedPoint128 {
    uint8 private constant RESOLUTION = 128;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;

    // returns a uq128x128 which represents the ratio of the numerator to the denominator
    function fraction(uint256 numerator, uint256 denominator) internal pure returns (uint256) {
        require(denominator > 0, 'DB0');
        if (numerator == 0) return 0;

        if (numerator <= uint128(-1)) {
            return (numerator << RESOLUTION) / denominator;
        } else {
            return FullMath.mulDiv(numerator, Q128, denominator);
        }
    }
}
