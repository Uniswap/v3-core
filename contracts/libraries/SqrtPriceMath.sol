// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './SafeCast.sol';
import './FixedPoint96.sol';
import './FixedPoint128.sol';

library SqrtPriceMath {
    using SafeMath for uint256;
    using SafeCast for uint256;

    function isMulSafe(uint256 x, uint256 y) private pure returns (bool) {
        return (x * y) / x == y;
    }

    function isAddSafe(uint256 x, uint256 y) private pure returns (bool) {
        return x <= uint256(-1) - y;
    }

    function divRoundingUp(uint256 x, uint256 d) private pure returns (uint256) {
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

    // calculate liquidity * sqrt(P) / (liquidity +- x * sqrt(P))
    // or, if this is impossible because of overflow,
    // liquidity / (liquidity / sqrt(P) +- x)
    function getNextPriceFromAmount0RoundingUp(
        FixedPoint96.uq64x96 memory sqrtP,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) private pure returns (FixedPoint96.uq64x96 memory) {
        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;

        if (
            isMulSafe(amount, sqrtP._x) &&
            (add ? isAddSafe(numerator1, amount * sqrtP._x) : numerator1 > amount * sqrtP._x)
        ) {
            uint256 denominator = add ? (numerator1 + amount * sqrtP._x) : (numerator1 - amount * sqrtP._x);
            return FixedPoint96.uq64x96(mulDivRoundingUp(numerator1, sqrtP._x, denominator).toUint160());
        }

        return
            FixedPoint96.uq64x96(
                divRoundingUp(
                    numerator1,
                    add ? (numerator1 / sqrtP._x).add(amount) : (numerator1 / sqrtP._x).sub(amount)
                )
                    .toUint160()
            );
    }

    // calculate sqrt(P) +- y / liquidity
    function getNextPriceFromAmount1RoundingDown(
        FixedPoint96.uq64x96 memory sqrtP,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) private pure returns (FixedPoint96.uq64x96 memory) {
        // if we're adding (subtracting), rounding down requires rounding the quotient down (up)
        // in both cases, avoid a mulDiv for most inputs
        uint256 quotient = add
            ? (
                amount <= uint160(-1)
                    ? (amount << FixedPoint96.RESOLUTION) / liquidity
                    : FullMath.mulDiv(amount, FixedPoint96.Q96, liquidity)
            )
            : (
                amount <= uint160(-1)
                    ? divRoundingUp(amount << FixedPoint96.RESOLUTION, liquidity)
                    : mulDivRoundingUp(amount, FixedPoint96.Q96, liquidity)
            );

        return
            FixedPoint96.uq64x96((add ? uint256(sqrtP._x).add(quotient) : uint256(sqrtP._x).sub(quotient)).toUint160());
    }

    function getNextPriceFromInput(
        FixedPoint96.uq64x96 memory sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (FixedPoint96.uq64x96 memory sqrtQ) {
        require(sqrtP._x > 0, 'SqrtPriceMath::getNextPriceFromInput: sqrtP cannot be zero');
        require(liquidity > 0, 'SqrtPriceMath::getNextPriceFromInput: liquidity cannot be zero');
        if (amountIn == 0) return sqrtP;

        // round to make sure that we don't pass the target price
        return
            zeroForOne
                ? getNextPriceFromAmount0RoundingUp(sqrtP, liquidity, amountIn, true)
                : getNextPriceFromAmount1RoundingDown(sqrtP, liquidity, amountIn, true);
    }

    function getNextPriceFromOutput(
        FixedPoint96.uq64x96 memory sqrtP,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) internal pure returns (FixedPoint96.uq64x96 memory sqrtQ) {
        require(sqrtP._x > 0, 'SqrtPriceMath::getNextPriceFromOutput: sqrtP cannot be zero');
        require(liquidity > 0, 'SqrtPriceMath::getNextPriceFromOutput: liquidity cannot be zero');
        if (amountOut == 0) return sqrtP;

        // round to make sure that we pass the target price
        return
            zeroForOne
                ? getNextPriceFromAmount1RoundingDown(sqrtP, liquidity, amountOut, false)
                : getNextPriceFromAmount0RoundingUp(sqrtP, liquidity, amountOut, false);
    }

    // calculate liquidity / sqrt(Q) - liquidity / sqrt(P), i.e.
    // liquidity * (sqrt(P) - sqrt(Q)) / (sqrt(P) * sqrt(Q))
    function getAmount0Delta(
        FixedPoint96.uq64x96 memory sqrtP, // square root of current price
        FixedPoint96.uq64x96 memory sqrtQ, // square root of target price
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        assert(sqrtP._x >= sqrtQ._x);

        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = sqrtP._x - sqrtQ._x;

        if (isMulSafe(sqrtP._x, sqrtQ._x)) {
            uint256 denominator = uint256(sqrtP._x) * sqrtQ._x;
            return
                roundUp
                    ? mulDivRoundingUp(numerator1, numerator2, denominator)
                    : FullMath.mulDiv(numerator1, numerator2, denominator);
        }

        return
            roundUp
                ? divRoundingUp(mulDivRoundingUp(numerator1, numerator2, sqrtP._x), sqrtQ._x)
                : FullMath.mulDiv(numerator1, numerator2, sqrtP._x) / sqrtQ._x;
    }

    // calculate liquidity * (sqrt(Q) - sqrt(P))
    function getAmount1Delta(
        FixedPoint96.uq64x96 memory sqrtP, // square root of current price
        FixedPoint96.uq64x96 memory sqrtQ, // square root of target price
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        assert(sqrtQ._x >= sqrtP._x);

        return
            roundUp
                ? mulDivRoundingUp(liquidity, sqrtQ._x - sqrtP._x, FixedPoint96.Q96)
                : FullMath.mulDiv(liquidity, sqrtQ._x - sqrtP._x, FixedPoint96.Q96);
    }

    // helpers to get signed deltas for use in setPosition
    // TODO not clear this is the right thing to do
    function getAmount0Delta(
        FixedPoint96.uq64x96 memory sqrtP, // square root of current price
        FixedPoint96.uq64x96 memory sqrtQ, // square root of target price
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        return
            liquidity < 0
                ? -getAmount0Delta(sqrtP, sqrtQ, uint128(-liquidity), false).toInt256()
                : getAmount0Delta(sqrtP, sqrtQ, uint128(liquidity), true).toInt256();
    }

    function getAmount1Delta(
        FixedPoint96.uq64x96 memory sqrtP, // square root of current price
        FixedPoint96.uq64x96 memory sqrtQ, // square root of target price
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        return
            liquidity < 0
                ? -getAmount1Delta(sqrtP, sqrtQ, uint128(-liquidity), false).toInt256()
                : getAmount1Delta(sqrtP, sqrtQ, uint128(liquidity), true).toInt256();
    }
}
