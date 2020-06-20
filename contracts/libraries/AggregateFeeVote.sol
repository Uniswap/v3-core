// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.6.8;

// functions for aggregate fee votes

struct Aggregate {
    int112 numerator;
    int112 denominator;
}

using AggregateFunctions for Aggregate;

library AggregateFunctions {    
    function add(Aggregate memory x, Aggregate memory y) internal pure returns (Aggregate memory) {
        // freshman sum
        return Aggregate({
            numerator: x.numerator + y.numerator,
            denominator: x.denominator + y.denominator
        });
    }

    function negate(Aggregate memory x) internal pure returns (Aggregate memory) {
        return Aggregate({
            numerator: -1 * x.numerator,
            denominator: -1 * x.denominator
        });
    }

    function averageFee(Aggregate memory x) internal pure returns (uint16) {
        return uint16(x.numerator / x.denominator);
    }
}
