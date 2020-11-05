// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';

import './SafeCast.sol';

library PriceMath {
    using SafeMath for *;
    using FixedPoint for FixedPoint.uq112x112;
    using SafeCast for *;

    uint16 public constant LP_FEE_BASE = 1e4; // i.e. 10k bips, 100%
    // 2**112 - 1, can be added to the input amount before truncating so that we always round up in getInputToRatio
    uint256 private constant ROUND_UP = 0xffffffffffffffffffffffffffff;

    // get a quote for a numerator amount from a denominator amount and a numerator/denominator price
    function getQuoteFromDenominator(uint144 denominatorAmount, FixedPoint.uq112x112 memory ratio)
        internal
        pure
        returns (uint256)
    {
        return mulDivRoundingUp(denominatorAmount, ratio._x, uint256(1) << 112);
    }

    // get a quote for a denominator amount from a numerator amount and a numerator/denominator price
    function getQuoteFromNumerator(uint144 numeratorAmount, FixedPoint.uq112x112 memory ratio)
        internal
        pure
        returns (uint256)
    {
        bool roundUp = mulmod(numeratorAmount, uint256(1) << 112, ratio._x) > 0;
        return ((uint256(numeratorAmount) << 112) / ratio._x) + (roundUp ? 1 : 0);
    }

    // amountIn here is assumed to have already been discounted by the fee
    function getAmountOut(
        uint112 reserveIn,
        uint112 reserveOut,
        uint112 amountIn
    ) internal pure returns (uint112) {
        return ((uint256(reserveOut) * amountIn) / (uint256(reserveIn) + amountIn)).toUint112();
    }

    function mulDivRoundingUp(
        uint256 x,
        uint256 y,
        uint256 d
    ) private pure returns (uint256) {
        bool roundUp = mulmod(x, y, d) > 0;
        return FullMath.mulDiv(x, y, d) + (roundUp ? 1 : 0);
    }

    function getInputToRatio(
        uint112 reserve0,
        uint112 reserve1,
        uint16 lpFee,
        FixedPoint.uq112x112 memory priceTarget, // always reserve1/reserve0
        bool zeroForOne
    ) internal pure returns (uint112 amountIn, uint112 reserveOutMinimum) {
        // short-circuit if we're already at or past the target price
        FixedPoint.uq112x112 memory price = FixedPoint.fraction(reserve1, reserve0);
        if (zeroForOne) {
            if (price._x <= priceTarget._x) return (0, reserve1);
        } else if (price._x >= priceTarget._x) return (0, reserve0);

        uint256 k = uint256(reserve0) * reserve1;

        // compute the square of output reserves (rounded up)
        uint256 reserveOutNextSquared;
        if (zeroForOne) {
            reserveOutNextSquared = mulDivRoundingUp(k, priceTarget._x, uint256(1) << 112);
        } else {
            reserveOutNextSquared = mulDivRoundingUp(k, uint256(1) << 112, priceTarget._x);
        }

        // compute exact output reserves (rounded up), because ceil(sqrt(ceil(x))) := ceil(sqrt(x)) ∀ x > 0
        reserveOutMinimum = Babylonian.sqrt(reserveOutNextSquared).toUint112();
        if (reserveOutNextSquared % reserveOutMinimum != 0) reserveOutMinimum = reserveOutMinimum.add(1).toUint112();

        // compute input reserves (rounded down), s.t. 1 more wei of input would lead to the price being exceeded
        uint112 reserveIn = zeroForOne ? reserve0 : reserve1;
        uint256 reserveInNext = zeroForOne
            ? (reserveOutMinimum << 112) / priceTarget._x
            : FullMath.mulDiv(reserveOutMinimum, priceTarget._x, uint256(1) << 112);
        uint112 amountInLessFee = uint112(reserveInNext - reserveIn);

        // compute the (rounded-up) amountIn scaled by the current fee
        bool roundUp = uint256(amountInLessFee) * LP_FEE_BASE % (LP_FEE_BASE - lpFee) > 0;
        amountIn = uint112(uint256(amountInLessFee) * LP_FEE_BASE / (LP_FEE_BASE - lpFee) + (roundUp ? 1 : 0));
    }
}
