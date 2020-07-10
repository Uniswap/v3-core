// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import "./SafeMath.sol";

import "../UniswapV3Pair.sol";

// functions for aggregate fee votes

library FeeVoting {
    struct Aggregate {
        int112 numerator;
        int112 denominator;
    }

    using SafeMathInt112 for int112;

    function add(Aggregate memory x, Aggregate memory y) internal pure returns (Aggregate memory) {
        // freshman sum
        return Aggregate({
            numerator: x.numerator.add(y.numerator),
            denominator: x.denominator.add(y.denominator)
        });
    }

    function sub(Aggregate memory x, Aggregate memory y) internal pure returns (Aggregate memory) {
        // freshman...difference
        return Aggregate({
            numerator: x.numerator.sub(y.numerator),
            denominator: x.denominator.sub(y.denominator)
        });
    }

    function totalFeeVote(UniswapV3Pair.Position memory position) pure internal returns (Aggregate memory) {
        return Aggregate({
            numerator: int112(position.feeVote) * int112(position.liquidity),
            denominator: int112(position.liquidity)
        });
    }

    function averageFee(Aggregate memory x) internal pure returns (uint16) {
        return uint16(x.numerator / x.denominator);
    }
}
