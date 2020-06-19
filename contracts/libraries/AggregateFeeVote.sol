// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.6.8;

// functions for aggregate fee votes

struct Aggregate {
    int112 numerator;
    int112 denominator;
}

library AggregateFeeVote {    
    function add(Aggregate memory x, Aggregate memory y) internal pure returns (Aggregate memory) {
        // freshman sum
        return Aggregate({
            numerator: x.numerator + y.numerator,
            denominator: y.denominator + y.denominator
        });
    }

    function averageFee(Aggregate memory x) internal pure returns (uint16) {
        return uint16(x.numerator / x.denominator);
    }
}
