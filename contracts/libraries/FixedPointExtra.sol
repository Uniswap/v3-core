// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import './SafeMath.sol';

// TODO: Move into @uniswap/lib
library FixedPointExtra {
    // multiply a UQ112x112 by an int and decode, returning an int
    // reverts on overflow
    function muli(FixedPoint.uq112x112 memory self, int other) internal pure returns (int) {
        uint144 z = FixedPoint.decode144(FixedPoint.mul(self, uint(other < 0 ? -other : other)));
        return other < 0 ? -int(z) : z;
    }

    // lower 112 bits, representing decimal portion of the number, i.e. 14 bytes
    uint224 public constant LOWER_MASK = 0xffff_ffff_ffff_ffff_ffff_ffff_ffff;

    // multiply a UQ112x112 by a UQ112x112, returning a UQ112x112
    function muluq(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory other)
        internal
        pure
        returns (FixedPoint.uq112x112 memory)
    {
        if (self._x == 0 || other._x == 0) {
            return FixedPoint.uq112x112(0);
        }
        uint112 upper_self = uint112(self._x >> 112); // * 2^0
        uint112 lower_self = uint112(self._x & LOWER_MASK); // * 2^-112
        uint112 upper_other = uint112(other._x >> 112); // * 2^0
        uint112 lower_other = uint112(other._x & LOWER_MASK); // * 2^-112

        // partial products
        uint224 uppers = uint224(upper_self) * upper_other; // * 2^0
        uint224 lowers = uint224(lower_self) * lower_other; // * 2^-224
        uint224 uppers_lowero = uint224(upper_self) * lower_other; // * 2^-112
        uint224 uppero_lowers = uint224(upper_other) * lower_self; // * 2^-112

        // so the bit shift does not overflow
        require(uppers <= uint112(-1), "FixedPointExtra: MULTIPLICATION_OVERFLOW");

        // this cannot exceed 256 bits, all values are 224 bits
        uint sum = uint(uppers << 112) + uppers_lowero + uppero_lowers + (lowers >> 112);

        // between 224 bits and 256 bits
        require(sum <= uint224(-1), "FixedPointExtra: MULTIPLICATION_OVERFLOW");

        // the multiplication results in a number too small to be represented in Q112.112
        require(sum > 0, "FixedPointExtra: MULTIPLICATION_UNDERFLOW");
        return FixedPoint.uq112x112(uint224(sum));
    }

    // divide a UQ112x112 by a UQ112x112, returning a UQ112x112
    function divuq(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory other)
        internal
        pure
        returns (FixedPoint.uq112x112 memory)
    {
        return muluq(self, FixedPoint.reciprocal(other));
    }
}
