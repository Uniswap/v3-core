// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/math/SignedSafeMath.sol';

import './FixedPoint128.sol';
import './SafeCast.sol';

import 'hardhat/console.sol';

library SqrtPriceMath {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    uint256 public constant Q64 = 0x10000000000000000;

    function getPriceAfterSwap(
        uint128 sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint128 sqrtQ) {
        require(sqrtP > 0, 'SqrtPriceMath::getPriceAfterSwap: sqrtP cannot be zero');
        require(liquidity > 0, 'SqrtPriceMath::getPriceAfterSwap: liquidity cannot be zero');
        if (amountIn == 0) return sqrtP;

        if (zeroForOne) {
            uint256 divisibleLiquidity = uint256(liquidity) << 64;
            // todo: precision loss in division
            sqrtQ = (divisibleLiquidity / (divisibleLiquidity / sqrtP).add(amountIn)).toUint128();
        } else {
            sqrtQ = uint256(sqrtP).add(FullMath.mulDiv(amountIn, Q64, liquidity)).toUint128();
        }
    }

    function getAmountDeltas(
        uint128 sqrtP,
        uint128 sqrtQ,
        uint128 liquidity
    ) internal pure returns (int256 amount0, int256 amount1) {
        require(sqrtP != 0 && sqrtQ != 0, 'SqrtPriceMath::getAmountDeltas: price cannot be 0');
        if (sqrtP == sqrtQ || liquidity == 0) return (0, 0);

        uint256 denom = uint256(sqrtP).mul(sqrtQ);
        uint256 amount0Abs = FullMath.mulDiv(
            liquidity,
            uint256(sqrtP < sqrtQ ? sqrtQ - sqrtP : sqrtP - sqrtQ) << 64,
            denom
        );
        amount0 = sqrtP < sqrtQ ? -amount0Abs.toInt256() : amount0Abs.toInt256();

        amount1 = int256(liquidity).mul(int256(sqrtQ) - int256(sqrtP)).div(int256(Q64));
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

        // max the q out to not exceed the target price
        sqrtQ = zeroForOne ? (sqrtQ < targetRoot ? targetRoot : sqrtQ) : (sqrtQ > targetRoot ? targetRoot : sqrtQ);
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
        amountIn = FullMath.mulDiv(amountIn, 1e6, 1e6 - feePips).add(2);
        if (amountIn > amountInMax) amountIn = amountInMax;
        if (amountOut > 0) amountOut--;
    }
}
