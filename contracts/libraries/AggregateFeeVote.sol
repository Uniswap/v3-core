// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.6.8;

import "./SafeMath112.sol";

// functions for aggregate fee votes

struct Aggregate {
    int112 numerator;
    int112 denominator;
}

library AggregateFunctions {
    using SafeMath112 for int112;

    function add(Aggregate memory x, Aggregate memory y) internal pure returns (Aggregate memory) {
        // freshman sum
        return Aggregate({
            numerator: x.numerator.add(y.numerator),
            denominator: x.denominator.add(y.denominator)
        });
    }

    function sub(Aggregate memory x, Aggregate memory y) internal pure returns (Aggregate memory) {
        // freshman... difference
        return Aggregate({
            numerator: x.numerator.sub(y.numerator),
            denominator: x.denominator.sub(y.denominator)
        });
    }

    function averageFee(Aggregate memory x) internal pure returns (uint16) {
        return uint16(x.numerator / x.denominator);
    }
}
