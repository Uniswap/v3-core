// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.4.0;

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
library FixedPoint64 {
    // range: [0, 2*64 - 1]
    // resolution: 1 / 2**64
    struct uq64x64 {
        uint128 _x;
    }

    uint8 internal constant RESOLUTION = 64;
    uint256 internal constant Q64 = 0x10000000000000000;
}
