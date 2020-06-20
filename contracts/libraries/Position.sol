// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.6.8;

import { Aggregate } from "./AggregateFeeVote.sol";

// functions for positions

struct Position {
    uint112 liquidity; // virtual liquidity shares, normalized to this range
    uint112 lastAdjustedLiquidity; // adjusted liquidity shares the last time fees were collected on this
    uint16 feeVote; // vote for fee, in 1/100ths of a bp
}

library PositionFunctions {
    function totalFeeVote(Position memory position) pure internal returns (Aggregate memory) {
        return Aggregate({
            numerator: int112(position.feeVote) * int112(position.lastAdjustedLiquidity),
            denominator: int112(position.lastAdjustedLiquidity)
        });
    }
}
