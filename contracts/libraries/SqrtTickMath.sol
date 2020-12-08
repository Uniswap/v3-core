// TODO consolidate this function into another library at some point and add tests
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import './FixedPoint64.sol';
import './TickMath.sol';

library SqrtTickMath {
    function getSqrtPriceFromTick(int24 tick) internal pure returns (FixedPoint64.uq64x64 memory sqrtQ) {
        assert(tick % 2 == 0);

        uint256 ratio = TickMath.getRatioAtTick(tick / 2) >> FixedPoint64.RESOLUTION;
        // TODO hopefully we can convince ourselves that this never happens
        require(ratio < uint128(-1), 'TODO');

        return FixedPoint64.uq64x64(uint128(ratio));
    }
}
