// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './SafeCast.sol';
import './FixedPoint64.sol';
import './PriceMath.sol';

library SqrtPriceMath {
    using SafeMath for uint128;
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
}
