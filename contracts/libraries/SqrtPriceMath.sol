// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './FeeMath.sol';
import './FullMath.sol';
import './LowGasSafeMath.sol';
import './UnsafeMath.sol';

import './SafeCast.sol';
import './FixedPoint96.sol';

/// @title Functions based on Q64.96 sqrt price and liquidity
/// @notice Contains the math that uses square root of price as a Q64.96 and liquidity to compute deltas
library SqrtPriceMath {
    using LowGasSafeMath for uint256;
    using SafeCast for uint256;

    /// @notice Get the next sqrt price given a delta of token0
    /// @param sqrtPX96 the starting price, i.e. before accounting for the token0 delta
    /// @param liquidity the amount of usable liquidity
    /// @param amount how much of token0 to add or remove from virtual reserves
    /// @param add whether to add or remove the amount of token0
    /// @return the price after adding or removing amount, depending on add
    /// @dev Always rounds up, because in the exact output case (increasing price) we need to move the price at least
    /// far enough to get the desired output amount, and in the exact input case (decreasing price) we need to move the
    /// price less in order to not send too much output.
    /// The most precise formula for this is liquidity * sqrtPX96 / (liquidity +- amount * sqrtPX96)
    /// If this is impossible because of overflow, we calculate liquidity / (liquidity / sqrtPX96 +- amount)
    function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) internal pure returns (uint160) {
        // we short circuit amount == 0 because the result is otherwise not guaranteed to equal the input price
        if (amount == 0) return sqrtPX96;
        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;

        uint256 product = amount * sqrtPX96;
        if (product / amount == sqrtPX96) {
            if (add) {
                uint256 denominator = numerator1 + product;
                if (denominator >= numerator1)
                    // always fits in 160 bits
                    return uint160(FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator));
            } else {
                uint256 denominator = numerator1 - product;
                if (denominator <= numerator1 && denominator != 0)
                    return FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator).toUint160();
            }
        }

        uint256 denominator1 = add ? (numerator1 / sqrtPX96).add(amount) : (numerator1 / sqrtPX96).sub(amount);
        require(denominator1 != 0);

        return UnsafeMath.divRoundingUp(numerator1, denominator1).toUint160();
    }

    /// @notice Get the next sqrt price given a delta of token1
    /// @param sqrtPX96 the starting price, i.e. before accounting for the token1 delta
    /// @param liquidity the amount of usable liquidity
    /// @param amount how much of token1 to add or remove from virtual reserves
    /// @param add whether to add or remove the amount of token1
    /// @return the price after adding or removing amount, depending on add
    /// @dev Always rounds down, because in the exact output case (decreasing price) we need to move the price at least
    /// far enough to get the desired output amount, and in the exact input case (increasing price) we need to move the
    /// price less in order to not send too much output.
    /// The formula we compute is lossless: sqrtPX96 +- amount / liquidity
    function getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) internal pure returns (uint160) {
        // if we're adding (subtracting), rounding down requires rounding the quotient down (up)
        // in both cases, avoid a mulDiv for most inputs
        uint256 quotient =
            add
                ? (
                    amount <= type(uint160).max
                        ? (amount << FixedPoint96.RESOLUTION) / liquidity
                        : FullMath.mulDiv(amount, FixedPoint96.Q96, liquidity)
                )
                : (
                    amount <= type(uint160).max
                        ? UnsafeMath.divRoundingUp(amount << FixedPoint96.RESOLUTION, liquidity)
                        : FullMath.mulDivRoundingUp(amount, FixedPoint96.Q96, liquidity)
                );

        return (add ? uint256(sqrtPX96).add(quotient) : uint256(sqrtPX96).sub(quotient)).toUint160();
    }

    /// @notice Get the next sqrt price given an input amount of token0 or token1
    /// @param sqrtPX96 the starting price, i.e. before accounting for the input amount
    /// @param liquidity the amount of usable liquidity
    /// @param amountIn how much of token0 or token1 is being swapped in
    /// @param zeroForOne whether the amount in is token0 or token1
    /// @return the price after adding the input amount to token0 or token1
    /// @dev Throws if price or liquidity are 0 or the next price is out of bounds
    function getNextSqrtPriceFromInput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtQX96) {
        require(sqrtPX96 > 0);
        require(liquidity > 0);

        // round to make sure that we don't pass the target price
        return
            zeroForOne
                ? getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
                : getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true);
    }

    /// @notice Get the next sqrt price given an output amount of token0 or token1
    /// @param sqrtPX96 the starting price, i.e. before accounting for the output amount
    /// @param liquidity the amount of usable liquidity
    /// @param amountOut how much of token0 or token1 is being swapped out
    /// @param zeroForOne whether the amount out is token0 or token1
    /// @return the price after removing the output amount of token0 or token1
    /// @dev Throws if price or liquidity are 0 or the next price is out of bounds
    function getNextSqrtPriceFromOutput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtQX96) {
        require(sqrtPX96 > 0);
        require(liquidity > 0);

        // round to make sure that we pass the target price
        return
            zeroForOne
                ? getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
                : getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false);
    }

    /// @notice Get the delta of amount0 between two prices
    /// @param sqrtPX96 the starting price
    /// @param sqrtQX96 the ending price
    /// @param liquidity the amount of usable liquidity
    /// @param roundUp whether to round the amount up or down
    /// @return the difference in virtual reserves of token0 between the two prices
    /// @dev Throws if the starting price is less than the ending price. To get the price in the other direction, swap
    /// the argument order.
    /// Calculates liquidity / sqrt(Q) - liquidity / sqrt(P), i.e. liquidity * (sqrt(P) - sqrt(Q)) / (sqrt(P) * sqrt(Q))
    function getAmount0Delta(
        uint160 sqrtPX96, // square root of current price
        uint160 sqrtQX96, // square root of target price
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        // TODO: this require should never be hit
        require(sqrtPX96 >= sqrtQX96);

        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = sqrtPX96 - sqrtQX96;

        return
            roundUp
                ? UnsafeMath.divRoundingUp(FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtPX96), sqrtQX96)
                : FullMath.mulDiv(numerator1, numerator2, sqrtPX96) / sqrtQX96;
    }

    /// @notice Get the delta of amount1 between two prices
    /// @param sqrtPX96 the starting price
    /// @param sqrtQX96 the ending price
    /// @param liquidity the amount of usable liquidity
    /// @param roundUp whether to round the amount up or down
    /// @return the difference in virtual reserves of token1 between the two prices
    /// @dev Throws if the starting price is greater than the ending price. To get the price in the other direction,
    /// swap the argument order.
    /// Calculates liquidity * (sqrt(Q) - sqrt(P))
    function getAmount1Delta(
        uint160 sqrtPX96, // square root of current price
        uint160 sqrtQX96, // square root of target price
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        // TODO: this require should never be hit
        require(sqrtQX96 >= sqrtPX96);

        return
            roundUp
                ? FullMath.mulDivRoundingUp(liquidity, sqrtQX96 - sqrtPX96, FixedPoint96.Q96)
                : FullMath.mulDiv(liquidity, sqrtQX96 - sqrtPX96, FixedPoint96.Q96);
    }

    /// @notice Helper that gets signed token0 delta from a liquidity delta
    /// @param sqrtPX96 the current price
    /// @param sqrtQX96 the target price
    /// @param liquidity the change in liquidity
    /// @return the difference in virtual reserves of token0 between two prices due to a given liquidity delta
    function getAmount0Delta(
        uint160 sqrtPX96,
        uint160 sqrtQX96,
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        return
            liquidity < 0
                ? -getAmount0Delta(sqrtPX96, sqrtQX96, uint128(-liquidity), false).toInt256()
                : getAmount0Delta(sqrtPX96, sqrtQX96, uint128(liquidity), true).toInt256();
    }

    /// @notice Helper that gets signed token1 delta from a liquidity delta
    /// @param sqrtPX96 the current price
    /// @param sqrtQX96 the target price
    /// @param liquidity the change in liquidity
    /// @return the difference in virtual reserves of token1 between two prices due to a given liquidity delta
    function getAmount1Delta(
        uint160 sqrtPX96,
        uint160 sqrtQX96,
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        return
            liquidity < 0
                ? -getAmount1Delta(sqrtPX96, sqrtQX96, uint128(-liquidity), false).toInt256()
                : getAmount1Delta(sqrtPX96, sqrtQX96, uint128(liquidity), true).toInt256();
    }
}
