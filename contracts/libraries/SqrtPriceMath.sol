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
            // liquidity * sqrt(P) / (liquidity + x * sqrt(P)), rounding up
            // TODO the max sqrtP value of uint160(-1) can limit the amountIn to 96 bits
            uint256 denominator = (uint256(liquidity) << FixedPoint96.RESOLUTION).add(amountIn.mul(sqrtP._x));
            sqrtQ = FixedPoint96.uq64x96(
                mulDivRoundingUp(uint256(liquidity) * FixedPoint96.Q96, sqrtP._x, denominator).toUint160()
            );
        } else {
            // calculate sqrt(P) + y / liquidity, i.e.
            // (liquidity * sqrt(P) + y) / liquidity
            if (sqrtP._x < uint128(-1)) {
                sqrtQ = FixedPoint96.uq64x96(
                    ((uint256(liquidity) * sqrtP._x).add(amountIn.mul(FixedPoint96.Q96)) / liquidity).toUint160()
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
        uint160 numerator2 = sqrtP._x - sqrtQ._x;
        uint256 denominator = uint256(sqrtP._x).mul(sqrtQ._x);

        if (roundUp) return mulDivRoundingUp(numerator1, numerator2, denominator);
        else return FullMath.mulDiv(numerator1, numerator2, denominator);
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
