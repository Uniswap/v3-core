// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import './SafeMath.sol';

// TODO: Move into @uniswap/lib
library FixedPointExtra {
    // multiply a UQ112x112 by an int and decode, returning an int
    // reverts on overflow
    function muli(FixedPoint.uq112x112 memory self, int y) internal pure returns (int) {
        uint144 z = FixedPoint.decode144(FixedPoint.mul(self, uint(y < 0 ? -y : y)));
        return y < 0 ? -int(z) : z;
    }

    // multiply a UQ112x112 by a UQ112x112, returning a UQ112x112
    function muluq(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory other)
        internal
        pure
        returns (FixedPoint.uq112x112 memory)
    {
        uint z = uint(self._x >> 96) * (other._x >> 96);
        require(z <= type(uint144).max, "FixedPointExtra: MULTIPLICATION_OVERFLOW");
        return FixedPoint.uq112x112(uint224(z << 80));
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
