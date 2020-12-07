// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './SafeCast.sol';
import './FixedPoint64.sol';
import './PriceMath.sol';

import 'hardhat/console.sol';

library SqrtPriceMath {
    using SafeMath for uint128;
    using SafeCast for int256;
    using SafeMath for uint256;
    using SafeCast for uint256;

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
            uint256 divisibleLiquidity = uint256(liquidity) << FixedPoint64.RESOLUTION;
            uint256 denominator = divisibleLiquidity.add(amountIn.mul(sqrtP._x));
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
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        assert(sqrtP._x >= sqrtQ._x);
        // calculate liquidity / sqrt(Q) - liquidity / sqrt(P), i.e.
        // liquidity * (sqrt(P) - sqrt(Q)) / (sqrt(P) * sqrt(Q)), rounding up
        return
            PriceMath.mulDivRoundingUp(liquidity << FixedPoint64.RESOLUTION, sqrtP._x - sqrtQ._x, sqrtP._x * sqrtQ._x);
    }

    function getAmount1Delta(
        FixedPoint64.uq64x64 memory sqrtP, // square root of current price
        FixedPoint64.uq64x64 memory sqrtQ, // square root of target price
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        assert(sqrtP._x <= sqrtQ._x);
        // calculate liquidity * (sqrt(Q) - sqrt(P)), rounding up
        return PriceMath.mulDivRoundingUp(liquidity, sqrtQ._x - sqrtP._x, FixedPoint64.Q64);
    }

    function mulDivRoundingUp(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256) {
        return FullMath.mulDiv(x, y, d) + (mulmod(x, y, d) > 0 ? 1 : 0);
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
        uint128 sqrtP = uint128(Babylonian.sqrt(price._x));
        uint128 targetRoot = uint128(Babylonian.sqrt(target._x));
        uint256 amountInLessFee = FullMath.mulDiv(amountInMax, 1e6 - feePips, 1e6);

        uint128 sqrtQ = getPriceAfterSwap(sqrtP, liquidity, amountInLessFee, zeroForOne);
        if (zeroForOne) {
            require(target._x <= price._x, 'SqrtPriceMath::computeSwap: target price must be less than current price');
            sqrtQ = sqrtQ < targetRoot ? targetRoot : sqrtQ;
        } else {
            require(
                target._x >= price._x,
                'SqrtPriceMath::computeSwap: target price must be greater than current price'
            );
            sqrtQ = sqrtQ > targetRoot ? targetRoot : sqrtQ;
        }

        priceAfter = sqrtQ == targetRoot ? target : FixedPoint128.uq128x128(uint256(sqrtQ)**2);

        (int256 amount0, int256 amount1) = getAmountDeltas(sqrtP, sqrtQ, liquidity);
        if (zeroForOne) {
            require(amount0 >= 0 && amount1 <= 0, 'blah1');
            amountIn = uint256(amount0);
            amountOut = uint256(-amount1);
        } else {
            require(amount0 <= 0 && amount1 >= 0, 'blah2');
            amountIn = uint256(amount1);
            amountOut = uint256(-amount0);
        }
        amountIn = FullMath.mulDiv(amountIn, 1e6, 1e6 - feePips).add(1);
    }
}
