pragma solidity =0.6.6;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

// TODO(moodysalem): Move into @uniswap/lib
library FixedPointExtra {
    // multiply a UQ112x112 by a uint, returning a UQ112x112
    // reverts on overflow
    function mul112(FixedPoint.uq112x112 memory self, uint y) internal pure returns (FixedPoint.uq112x112 memory) {
        uint z;
        require(y == 0 || (z = uint(self._x) * y) / y == uint(self._x), "FixedPoint: MULTIPLICATION_OVERFLOW");
        require(z <= 2**224, "FixedPoint: MULTIPLICATION_OVERFLOW");
        return FixedPoint.uq112x112(uint224(z));
    }

    // add a UQ112x112 to a UQ112x112, returning a UQ112x112
    // reverts on overflow
    function add(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory y) internal pure returns (FixedPoint.uq112x112 memory) {
        uint224 z;
        require((z = self._x + y._x) >= self._x, 'FixedPointExtra: ADD_OVERFLOW');
        return FixedPoint.uq112x112(z);
    }

    // multiply a UQ112x112 by a UQ112x112, returning a UQ112x112
    function uqmul112(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory x) internal pure returns (FixedPoint.uq112x112 memory) {
        // TODO: implement this
        return self;
    }

    // divide a UQ112x112 by a UQ112x112, returning a UQ112x112
    function uqdiv112(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory x) internal pure returns (FixedPoint.uq112x112 memory) {
        // TODO: implement this
        return self;
    }

}
