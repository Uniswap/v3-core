// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.11;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import '../libraries/FixedPointExtra.sol';

contract FixedPointExtraTest {
    function muluq(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory other)
    public
    pure
    returns (FixedPoint.uq112x112 memory) {
        return FixedPointExtra.muluq(self, other);
    }

    function muluqGasUsed(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory other) view public returns (uint) {
        uint gasBefore = gasleft();
        FixedPointExtra.muluq(self, other);
        uint gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }

    function divuq(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory other)
    public
    pure
    returns (FixedPoint.uq112x112 memory) {
        return FixedPointExtra.divuq(self, other);
    }

    function divuqGasUsed(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory other) view public returns (uint) {
        uint gasBefore = gasleft();
        FixedPointExtra.divuq(self, other);
        uint gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }
}
