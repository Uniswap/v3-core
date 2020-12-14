// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.4.0;

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
library FixedPoint96 {
    // range: [0, 2*64 - 1]
    // resolution: 1 / 2**96
    struct uq64x96 {
        uint160 _x;
    }

    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}
