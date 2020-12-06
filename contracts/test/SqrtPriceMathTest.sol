// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import '../libraries/SqrtPriceMath.sol';

contract SqrtPriceMathTest {
    function getPriceAfterSwap(
        uint128 sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external pure returns (uint128 sqrtQ) {
        return SqrtPriceMath.getPriceAfterSwap(sqrtP, liquidity, amountIn, zeroForOne);
    }
}
