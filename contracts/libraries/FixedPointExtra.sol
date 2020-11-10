// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

library FixedPointExtra {
    // reverts on overflow
    function sub(FixedPoint.uq112x112 memory x, FixedPoint.uq112x112 memory y)
        internal
        pure
        returns (FixedPoint.uq112x112 memory)
    {
        return FixedPoint.uq112x112(uint224(SafeMath.sub(x._x, y._x)));
    }

    // reverts on overflow
    function add(FixedPoint.uq112x112 memory x, FixedPoint.uq112x112 memory y)
        internal
        pure
        returns (FixedPoint.uq112x112 memory)
    {
        uint256 sum = uint256(x._x) + y._x;
        require(sum <= uint224(-1), 'FixedPointExtra::add: OVERFLOW');
        return FixedPoint.uq112x112(uint224(sum));
    }
}
