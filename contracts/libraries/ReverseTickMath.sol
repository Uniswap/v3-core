// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import './TickMath.sol';

// calculates ticks from prices
library ReverseTickMath {
    // gets the tick from a price, assuming the tick is gte the lower and lt the upper bound
    function getTickFromPrice(
        FixedPoint.uq112x112 memory price,
        int16 lowerBound,
        int16 upperBound
    ) internal pure returns (int16 tick) {
        require(
            lowerBound < upperBound,
            'ReverseTickMath::getTickFromPrice: lower bound must be less than upper bound'
        );

        tick = (lowerBound + upperBound) >> 1;

        while (upperBound - lowerBound > 1) {
            FixedPoint.uq112x112 memory middle = TickMath.getRatioAtTick(tick);

            if (price._x >= middle._x) {
                lowerBound = tick;
            } else {
                upperBound = tick;
            }
            tick = (lowerBound + upperBound) >> 1;
        }

        return tick;
    }
}
