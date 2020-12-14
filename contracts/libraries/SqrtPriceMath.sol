// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/Math.sol';

import './SafeCast.sol';
import './FixedPoint96.sol';
import './FixedPoint128.sol';

library SqrtPriceMath {
    using SafeMath for uint128;
    using SafeCast for int256;
    using SafeMath for uint256;
    using SafeCast for uint256;

    function divRoundingUp(uint256 x, uint256 d) internal pure returns (uint256) {
        // addition is safe because (uint256(-1) / 1) + (uint256(-1) % 1 > 0 ? 1 : 0) == uint256(-1)
        return (x / d) + (x % d > 0 ? 1 : 0);
    }

    function mulDivRoundingUp(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256) {
        return FullMath.mulDiv(x, y, d) + (mulmod(x, y, d) > 0 ? 1 : 0);
    }

    function getNextPrice(
        FixedPoint96.uq64x96 memory sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (FixedPoint96.uq64x96 memory sqrtQ) {
        require(sqrtP._x > 0, 'SqrtPriceMath::getNextPrice: sqrtP cannot be zero');
        require(liquidity > 0, 'SqrtPriceMath::getNextPrice: liquidity cannot be zero');
        if (amountIn == 0) return sqrtP;

        if (zeroForOne) {
            // calculate liquidity / ((liquidity / sqrt(P)) + x), i.e.
            // liquidity * sqrt(P) / (liquidity + x * sqrt(P))
            // rounds up in the division because we do not want to go past the next price
            uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
            if (amountIn <= uint96(-1)) {
                uint256 denominator = numerator1.add(amountIn.mul(sqrtP._x));
                sqrtQ = FixedPoint96.uq64x96(mulDivRoundingUp(numerator1, sqrtP._x, denominator).toUint160());
            } else {
                sqrtQ = FixedPoint96.uq64x96(
                    divRoundingUp(numerator1, (numerator1 / sqrtP._x).add(amountIn)).toUint160()
                );
            }
        } else {
            // calculate sqrt(P) + y / liquidity
            // rounds down in the division because we do not want to go past the next price

            // avoid a mulDiv for most inputs
            if (amountIn <= uint160(-1)) {
                sqrtQ = FixedPoint96.uq64x96(
                    uint256(sqrtP._x).add((amountIn << FixedPoint96.RESOLUTION) / liquidity).toUint160()
                );
            } else {
                sqrtQ = FixedPoint96.uq64x96(
                    uint256(sqrtP._x).add(FullMath.mulDiv(amountIn, FixedPoint96.Q96, liquidity)).toUint160()
                );
            }
        }
    }

    function getAmount0Delta(
        FixedPoint96.uq64x96 memory sqrtP, // square root of current price
        FixedPoint96.uq64x96 memory sqrtQ, // square root of target price
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        assert(sqrtP._x >= sqrtQ._x);

        // calculate liquidity / sqrt(Q) - liquidity / sqrt(P), i.e.
        // liquidity * (sqrt(P) - sqrt(Q)) / (sqrt(P) * sqrt(Q)), rounding up
        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = uint256(sqrtP._x) - sqrtQ._x;
        uint256 denominator = uint256(sqrtP._x) * sqrtQ._x;
        if (denominator / sqrtP._x == sqrtP._x) {
            if (roundUp) return mulDivRoundingUp(numerator1, numerator2, denominator);
            else return FullMath.mulDiv(numerator1, numerator2, denominator);
        } else {
            if (roundUp) return divRoundingUp(mulDivRoundingUp(numerator1, numerator2, sqrtP._x), sqrtQ._x);
            else return FullMath.mulDiv(numerator1, numerator2, sqrtP._x) / sqrtQ._x;
        }
    }

    function getAmount1Delta(
        FixedPoint96.uq64x96 memory sqrtP, // square root of current price
        FixedPoint96.uq64x96 memory sqrtQ, // square root of target price
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        assert(sqrtP._x <= sqrtQ._x);

        // calculate liquidity * (sqrt(Q) - sqrt(P)), rounding up
        uint256 numerator1 = uint256(liquidity);
        uint256 numerator2 = sqrtQ._x - sqrtP._x;

        bool add1 = roundUp ? (mulmod(numerator1, numerator2, FixedPoint96.Q96) > 0) : false;
        return FullMath.mulDiv(numerator1, numerator2, FixedPoint96.Q96) + (add1 ? 1 : 0);
    }

    // helpers to get signed deltas for use in setPosition
    // TODO not clear this is the right thing to do
    function getAmount0Delta(
        FixedPoint96.uq64x96 memory sqrtP, // square root of current price
        FixedPoint96.uq64x96 memory sqrtQ, // square root of target price
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        if (liquidity < 0) return -getAmount0Delta(sqrtP, sqrtQ, uint128(-liquidity), false).toInt256();
        else return getAmount0Delta(sqrtP, sqrtQ, uint128(liquidity), true).toInt256();
    }

    function getAmount1Delta(
        FixedPoint96.uq64x96 memory sqrtP, // square root of current price
        FixedPoint96.uq64x96 memory sqrtQ, // square root of target price
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        if (liquidity < 0) return -getAmount1Delta(sqrtP, sqrtQ, uint128(-liquidity), false).toInt256();
        else return getAmount1Delta(sqrtP, sqrtQ, uint128(liquidity), true).toInt256();
    }
}
