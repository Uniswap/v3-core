// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.0;

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))
library FixedPoint128 {
    uint8 private constant RESOLUTION = 128;
    uint256 internal constant Q128 = 0x100000000000000000000000000000000;
}
