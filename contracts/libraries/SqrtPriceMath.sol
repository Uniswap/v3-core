// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/Math.sol';

import './SafeCast.sol';
import './FixedPoint64.sol';
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

    function getPriceAfterSwap(
        FixedPoint64.uq64x64 memory sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (FixedPoint64.uq64x64 memory sqrtQ) {
        require(sqrtP._x > 0, 'SqrtPriceMath::getPriceAfterSwap: sqrtP cannot be zero');
        require(liquidity > 0, 'SqrtPriceMath::getPriceAfterSwap: liquidity cannot be zero');
        if (amountIn == 0) return sqrtP;

        if (zeroForOne) {
            // calculate liquidity / ((liquidity / sqrt(P)) + x), i.e.
            // liquidity * sqrt(P) / (liquidity + x * sqrt(P))
            // TODO can revert from overflow
            uint256 denominator = (uint256(liquidity) << FixedPoint64.RESOLUTION).add(amountIn.mul(sqrtP._x));
            sqrtQ = FixedPoint64.uq64x64(
                FullMath.mulDiv(uint256(liquidity) * sqrtP._x, FixedPoint64.Q64, denominator).toUint128()
            );
        } else {
            // calculate sqrt(P) + y / liquidity, i.e.
            // calculate (liquidity * sqrt(P) + y) / liquidity
            // TODO can revert from overflow
            sqrtQ = FixedPoint64.uq64x64(
                ((uint256(liquidity) * sqrtP._x).add(amountIn.mul(FixedPoint64.Q64)) / liquidity).toUint128()
            );
        }
    }

    function getAmount0Delta(
        FixedPoint64.uq64x64 memory sqrtP, // square root of current price
        FixedPoint64.uq64x64 memory sqrtQ, // square root of target price
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        assert(sqrtP._x >= sqrtQ._x);

        // calculate liquidity / sqrt(Q) - liquidity / sqrt(P), i.e.
        // liquidity * (sqrt(P) - sqrt(Q)) / (sqrt(P) * sqrt(Q)), rounding up
        uint256 numerator1 = uint256(liquidity) << FixedPoint64.RESOLUTION;
        uint128 numerator2 = sqrtP._x - sqrtQ._x;
        uint256 denominator = uint256(sqrtP._x) * sqrtQ._x;

        if (roundUp) return mulDivRoundingUp(numerator1, numerator2, denominator);
        else return FullMath.mulDiv(numerator1, numerator2, denominator);
    }

    function getAmount1Delta(
        FixedPoint64.uq64x64 memory sqrtP, // square root of current price
        FixedPoint64.uq64x64 memory sqrtQ, // square root of target price
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        assert(sqrtP._x <= sqrtQ._x);

        // calculate liquidity * (sqrt(Q) - sqrt(P)), rounding up
        uint256 numerator = uint256(liquidity) * (sqrtQ._x - sqrtP._x);

        bool add1 = roundUp ? (numerator % FixedPoint64.Q64 > 0) : false;
        return numerator / FixedPoint64.Q64 + (add1 ? 1 : 0);
    }

    // helpers to get signed deltas for use in setPosition
    // TODO not clear this is the right thing to do
    function getAmount0Delta(
        FixedPoint64.uq64x64 memory sqrtP, // square root of current price
        FixedPoint64.uq64x64 memory sqrtQ, // square root of target price
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        if (liquidity < 0) return -getAmount0Delta(sqrtP, sqrtQ, uint128(-liquidity), false).toInt256();
        else return getAmount0Delta(sqrtP, sqrtQ, uint128(liquidity), true).toInt256();
    }

    function getAmount1Delta(
        FixedPoint64.uq64x64 memory sqrtP, // square root of current price
        FixedPoint64.uq64x64 memory sqrtQ, // square root of target price
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        if (liquidity < 0) return -getAmount1Delta(sqrtP, sqrtQ, uint128(-liquidity), false).toInt256();
        else return getAmount1Delta(sqrtP, sqrtQ, uint128(liquidity), true).toInt256();
    }

    function computeSwap(
        FixedPoint128.uq128x128 memory price,
        FixedPoint128.uq128x128 memory target,
        uint128 liquidity,
        uint256 amountInMax,
        uint24 feePips,
        bool zeroForOne
    )
        internal
        pure
        returns (
            FixedPoint128.uq128x128 memory priceAfter,
            uint256 amountIn,
            uint256 amountOut
        )
    {
        FixedPoint64.uq64x64 memory sqrtP = FixedPoint64.uq64x64(uint128(Babylonian.sqrt(price._x)));
        FixedPoint64.uq64x64 memory sqrtQ = FixedPoint64.uq64x64(uint128(Babylonian.sqrt(target._x)));

        // get the input required to reach or surpass the target price
        if (zeroForOne) {
            assert(price._x >= target._x);
            amountIn = getAmount0Delta(sqrtP, sqrtQ, liquidity, true);
        } else {
            assert(price._x <= target._x);
            amountIn = getAmount1Delta(sqrtP, sqrtQ, liquidity, true);
        }

        // scale the input amount up by the fee, rounding up
        amountIn = mulDivRoundingUp(amountIn, 1e6, 1e6 - feePips);

        // cap the input amount
        amountIn = Math.min(amountIn, amountInMax);

        // get the post-swap price
        sqrtQ = getPriceAfterSwap(sqrtP, liquidity, FullMath.mulDiv(amountIn, 1e6 - feePips, 1e6), zeroForOne);
        priceAfter = FixedPoint128.uq128x128(uint256(sqrtQ._x)**2);

        // get the output amount, rounding down
        if (zeroForOne) amountOut = getAmount1Delta(sqrtQ, sqrtP, liquidity, false);
        else amountOut = getAmount0Delta(sqrtQ, sqrtP, liquidity, false);
    }
}
