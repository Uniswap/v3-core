// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.6.8;

// a library for performing various math operations

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }
}
