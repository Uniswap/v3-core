// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import "./SafeMath.sol";

import "../UniswapV3Pair.sol";

library FeeVoting {
    using SafeMath for uint;
    using SafeMath for uint112;
    using SafeMath for  int;
    using SafeMath for  int128;

    struct Aggregate {
        int128 numerator;
        int128 denominator;
    }

    function add(Aggregate memory self, Aggregate memory y) internal pure returns (Aggregate memory z) {
        // freshman sum
        z = Aggregate({
            numerator: (int(self.numerator) + y.numerator).itoInt128(),
            denominator: (int(self.denominator) + y.denominator).itoInt128()
        });
    }

    function sub(Aggregate memory self, Aggregate memory y) internal pure returns (Aggregate memory z) {
        // freshman...difference
        z = Aggregate({
            numerator: self.numerator.isub(y.numerator).itoInt128(),
            denominator: self.denominator.isub(y.denominator).itoInt128()
        });
    }

    function totalFeeVote(UniswapV3Pair.Position memory position) internal pure returns (Aggregate memory z) {
        z = Aggregate({
            numerator: position.liquidity.mul(position.feeVote).toInt128(),
            denominator: position.feeVote == 0 ? 0 : position.liquidity
        });
    }

    function averageFee(Aggregate memory self) internal pure returns (uint16 z) {
        z = self.denominator == 0 ? 0 : uint16(self.numerator / self.denominator);
    }
}
