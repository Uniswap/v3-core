// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import './SafeMath.sol';

// TODO: Move into @uniswap/lib
library FixedPointExtra {
    // multiply a UQ112x112 by an int and decode, returning an int
    // reverts on overflow
    function muli(FixedPoint.uq112x112 memory self, int256 other) internal pure returns (int256) {
        uint144 z = FixedPoint.decode144(FixedPoint.mul(self, uint256(other < 0 ? -other : other)));
        return other < 0 ? -int256(z) : z;
    }

    // lower 112 bits, representing decimal portion of the number, i.e. 14 bytes
    uint224 public constant LOWER_MASK = 0xffff_ffff_ffff_ffff_ffff_ffff_ffff;

    function muluq(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory other)
        internal
        pure
        returns (FixedPoint.uq112x112 memory)
    {
        if (self._x == 0 || other._x == 0) {
            return FixedPoint.uq112x112(0);
        }
        uint112 upper_self = uint112(self._x >> 112);
        uint112 lower_self = uint112(self._x & LOWER_MASK);
        uint112 upper_other = uint112(other._x >> 112);
        uint112 lower_other = uint112(other._x & LOWER_MASK);

        uint224 uppers = uint224(upper_self) * upper_other;
        uint224 lowers = uint224(lower_self) * lower_other;
        uint224 uppers_lowero = uint224(upper_self) * lower_other;
        uint224 uppero_lowers = uint224(upper_other) * lower_self;

        require(uppers <= uint112(-1), 'FixedPointExtra: MULTIPLICATION_OVERFLOW');

        uint256 sum = uint256(uppers << 112) + uppers_lowero + uppero_lowers + (lowers >> 112);

        require(sum <= uint224(-1), 'FixedPointExtra: MULTIPLICATION_OVERFLOW');

        require(sum > 0, 'FixedPointExtra: MULTIPLICATION_UNDERFLOW');
        return FixedPoint.uq112x112(uint224(sum));
    }

    function divuq(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory other)
        internal
        pure
        returns (FixedPoint.uq112x112 memory)
    {
        if (self._x == other._x) {
            return FixedPoint.uq112x112(1 << 112);
        }
        return muluq(self, FixedPoint.reciprocal(other));
    }
}
