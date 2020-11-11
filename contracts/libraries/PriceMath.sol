// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@openzeppelin/contracts/math/Math.sol';

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';

import './SafeCast.sol';

library PriceMath {
    using SafeCast for uint256;

    uint16 public constant LP_FEE_BASE = 1e4; // i.e. 10k bips, 100%

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
        return mulDivRoundingUp(numeratorAmount, uint256(1) << 112, ratio._x);
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
    ) internal pure returns (uint256) {
        return FullMath.mulDiv(x, y, d) + (mulmod(x, y, d) > 0 ? 1 : 0);
    }

    function getInputToRatio(
        uint112 reserve0,
        uint112 reserve1,
        uint16 lpFee,
        FixedPoint.uq112x112 memory priceTarget, // always reserve1/reserve0
        bool zeroForOne
    ) internal pure returns (uint112 amountIn, uint112 amountOut) {
        // short-circuit if we're already at or past the target price
        FixedPoint.uq112x112 memory price = FixedPoint.fraction(reserve1, reserve0);
        if (zeroForOne) {
            if (price._x <= priceTarget._x) return (0, 0);
        } else if (price._x >= priceTarget._x) return (0, 0);

        uint256 k = uint256(reserve0) * reserve1;

        // compute the square of input reserves (rounded up)
        uint256 reserveInSquared = zeroForOne
            ? mulDivRoundingUp(k, uint256(1) << 112, priceTarget._x)
            : mulDivRoundingUp(k, priceTarget._x, uint256(1) << 112);

        // compute input reserves (rounded up) exactly (because ceil(sqrt(ceil(x))) := ceil(sqrt(x)) ∀ x > 0)
        uint256 reserveInRequired = Babylonian.sqrt(reserveInSquared);
        if (reserveInRequired**2 < reserveInSquared) reserveInRequired++;

        // compute minimum output reserves s.t. we are guaranteed not to exceed the target price
        uint256 reserveOutMinimum = zeroForOne
            ? mulDivRoundingUp(reserveInRequired, priceTarget._x, uint256(1) << 112)
            : mulDivRoundingUp(reserveInRequired, uint256(1) << 112, priceTarget._x);

        // if necessary, increase the required input reserves s.t. are <1 wei from exceeding the target price
        reserveInRequired = Math.max(
            reserveInRequired,
            zeroForOne
                ? FullMath.mulDiv(reserveOutMinimum, uint256(1) << 112, priceTarget._x)
                : FullMath.mulDiv(reserveOutMinimum, priceTarget._x, uint256(1) << 112)
        );

        // TODO is this necessary? i think so
        require(reserveInRequired <= uint112(-1), 'PriceMath: EXCESSIVE_INPUT_REQUIRED');
        amountIn = uint112(reserveInRequired) - (zeroForOne ? reserve0 : reserve1);

        // TODO is this necessary? maybe not
        assert(reserveOutMinimum <= (zeroForOne ? reserve1 : reserve0));
        amountOut = (zeroForOne ? reserve1 : reserve0) - uint112(reserveOutMinimum);

        // scale amountIn by the current fee (rounding up)
        // TODO is the toUint112() necessary?
        amountIn = mulDivRoundingUp(amountIn, LP_FEE_BASE, LP_FEE_BASE - lpFee).toUint112();
    }
}
