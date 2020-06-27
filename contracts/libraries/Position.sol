// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.6.8;

import { Aggregate } from "./AggregateFeeVote.sol";

// functions for positions

// For example, if there has been, 

// liquidity stays constant. 

struct Position {
    // liquidity is adjusted virtual liquidity tokens (sqrt(xy)), not counting fees since last sync
    // these units do not increase over time with accumulated fees. it is always sqrt(xy)
    // liquidity stays the same if pinged with 0 as liquidityDelta, because accumulated fees are collected when synced
    uint112 liquidity;
    // lastNormalizedLiquidity is (liquidity / kGrowthInRange) as of last sync
    // lastNormalizedLiquidity is smaller than liquidity if any fees have previously been earned in the range
    // and gets even smaller when pinged if any fees were earned in the range
    uint112 lastNormalizedLiquidity;
    uint16 feeVote; // this provider's vote for fee, in 1/100ths of a bp
}

library PositionFunctions {
    function totalFeeVote(Position memory position) pure internal returns (Aggregate memory) {
        return Aggregate({
            numerator: int112(position.feeVote) * int112(position.liquidity),
            denominator: int112(position.liquidity)
        });
    }
}
