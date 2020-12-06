// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import './FixedPoint128.sol';
import './SafeCast.sol';

library SqrtPriceMath {
    using SafeCast for uint256;
    using SafeMath for uint256;

    uint256 public constant Q64 = 2**64;

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
            sqrtQ = (divisibleLiquidity / ((divisibleLiquidity / sqrtP).add(amountIn))).toUint128();
        } else {
            sqrtQ = uint256(sqrtP).add(FullMath.mulDiv(amountIn, Q64, liquidity)).toUint128();
        }
    }
}
