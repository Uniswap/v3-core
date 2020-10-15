// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.11;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

contract FixedPointGasTest {
    function muluqGasUsed(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory other)
        public
        view
        returns (uint256)
    {
        uint256 gasBefore = gasleft();
        FixedPoint.muluq(self, other);
        uint256 gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }

    function divuqGasUsed(FixedPoint.uq112x112 memory self, FixedPoint.uq112x112 memory other)
        public
        view
        returns (uint256)
    {
        uint256 gasBefore = gasleft();
        FixedPoint.divuq(self, other);
        uint256 gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }
}
