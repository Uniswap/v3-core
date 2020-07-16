// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import 'abdk-libraries-solidity/ABDKMathQuad.sol';

// TODO: Move into @uniswap/lib
library FixedPointExtra {
    uint8 private constant RESOLUTION = 112;

    // multiply a UQ112x112 by an int and decode, returning an int112
    // TODO: fix
    // reverts on overflow
    function muli(FixedPoint.uq112x112 memory self, int y) internal pure returns (int112) {
        int z;
        require(y == 0 || (z = int(self._x) * y) / y == int(self._x), "FixedPoint: MULTIPLICATION_OVERFLOW");
        require(z <= 2**224, "FixedPoint: MULTIPLICATION_OVERFLOW");
        return int112(z >> RESOLUTION);
    }

    // multiply a UQ112x112 by a UQ112x112, returning a UQ112x112
    function uqmul112(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory x) internal pure returns (FixedPoint.uq112x112 memory) {
        // TODO: implement this
        // silly hack to avoid linter error
        return true ? self : x;
    }

    // divide a UQ112x112 by a UQ112x112, returning a UQ112x112
    function uqdiv112(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory x) internal pure returns (FixedPoint.uq112x112 memory) {
        // TODO: implement this
        // silly hack to avoid linter error
        return true ? self : x;
    }
}
