// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import "./SafeMath.sol";

import "../UniswapV3Pair.sol";

// functions for aggregate fee votes

library FeeVoting {
    struct Aggregate {
        int128 numerator;
        int128 denominator;
    }

    using SafeMath for uint;
    using SafeMath for uint112;
    using SafeMath for  int;
    using SafeMath for  int128;

    function add(Aggregate memory x, Aggregate memory y) internal pure returns (Aggregate memory z) {
        // freshman sum
        z = Aggregate({
            numerator: (int(x.numerator) + y.numerator).itoInt128(),
            denominator: (int(x.denominator) + y.denominator).itoInt128()
        });
    }

    function sub(Aggregate memory x, Aggregate memory y) internal pure returns (Aggregate memory) {
        // freshman...difference
        return Aggregate({
            numerator: x.numerator.isub(y.numerator).itoInt128(),
            denominator: x.denominator.isub(y.denominator).itoInt128()
        });
    }

    function totalFeeVote(UniswapV3Pair.Position memory position) internal pure returns (Aggregate memory) {
        return Aggregate({
            numerator: position.liquidity.mul(position.feeVote).toInt128(),
            denominator: position.feeVote == 0 ? 0 : uint(position.liquidity).toInt128()
        });
    }

    function averageFee(Aggregate memory y) internal pure returns (uint16 z) {
        z = y.denominator == 0 ? 0 : uint16(y.numerator / y.denominator);
    }
}
