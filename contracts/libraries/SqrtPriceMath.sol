// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './FullMath.sol';
import './SafeMath.sol';

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
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) private pure returns (uint160) {
        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;

        if (isMulSafe(amount, sqrtP) && (add ? isAddSafe(numerator1, amount * sqrtP) : numerator1 > amount * sqrtP)) {
            uint256 denominator = add ? (numerator1 + amount * sqrtP) : (numerator1 - amount * sqrtP);
            return mulDivRoundingUp(numerator1, sqrtP, denominator).toUint160();
        }

        return
            divRoundingUp(numerator1, add ? (numerator1 / sqrtP).add(amount) : (numerator1 / sqrtP).sub(amount))
                .toUint160();
    }

    // calculate sqrt(P) +- y / liquidity
    function getNextPriceFromAmount1RoundingDown(
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) private pure returns (uint160) {
        // if we're adding (subtracting), rounding down requires rounding the quotient down (up)
        // in both cases, avoid a mulDiv for most inputs
        uint256 quotient =
            add
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

        return (add ? uint256(sqrtP).add(quotient) : uint256(sqrtP).sub(quotient)).toUint160();
    }

    function getNextPriceFromInput(
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtQ) {
        require(sqrtP > 0, 'P');
        require(liquidity > 0, 'L');
        if (amountIn == 0) return sqrtP;

        // round to make sure that we don't pass the target price
        return
            zeroForOne
                ? getNextPriceFromAmount0RoundingUp(sqrtP, liquidity, amountIn, true)
                : getNextPriceFromAmount1RoundingDown(sqrtP, liquidity, amountIn, true);
    }

    function getNextPriceFromOutput(
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtQ) {
        require(sqrtP > 0, 'P');
        require(liquidity > 0, 'L');
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
        uint160 sqrtP, // square root of current price
        uint160 sqrtQ, // square root of target price
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        assert(sqrtP >= sqrtQ);

        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = sqrtP - sqrtQ;

        if (isMulSafe(sqrtP, sqrtQ)) {
            uint256 denominator = uint256(sqrtP) * sqrtQ;
            return
                roundUp
                    ? mulDivRoundingUp(numerator1, numerator2, denominator)
                    : FullMath.mulDiv(numerator1, numerator2, denominator);
        }

        return
            roundUp
                ? divRoundingUp(mulDivRoundingUp(numerator1, numerator2, sqrtP), sqrtQ)
                : FullMath.mulDiv(numerator1, numerator2, sqrtP) / sqrtQ;
    }

    // calculate liquidity * (sqrt(Q) - sqrt(P))
    function getAmount1Delta(
        uint160 sqrtP, // square root of current price
        uint160 sqrtQ, // square root of target price
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        assert(sqrtQ >= sqrtP);

        return
            roundUp
                ? mulDivRoundingUp(liquidity, sqrtQ - sqrtP, FixedPoint96.Q96)
                : FullMath.mulDiv(liquidity, sqrtQ - sqrtP, FixedPoint96.Q96);
    }

    // helpers to get signed deltas for use in setPosition
    // TODO not clear this is the right thing to do
    function getAmount0Delta(
        uint160 sqrtP, // square root of current price
        uint160 sqrtQ, // square root of target price
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        return
            liquidity < 0
                ? -getAmount0Delta(sqrtP, sqrtQ, uint128(-liquidity), false).toInt256()
                : getAmount0Delta(sqrtP, sqrtQ, uint128(liquidity), true).toInt256();
    }

    function getAmount1Delta(
        uint160 sqrtP, // square root of current price
        uint160 sqrtQ, // square root of target price
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        return
            liquidity < 0
                ? -getAmount1Delta(sqrtP, sqrtQ, uint128(-liquidity), false).toInt256()
                : getAmount1Delta(sqrtP, sqrtQ, uint128(liquidity), true).toInt256();
    }
}
