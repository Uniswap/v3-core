// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/LiquidityFromAmounts.sol';

contract LiquidityFromAmountsTest {
    function getLiquidityDeltaForAmount0(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 amount0
    ) external pure returns (uint256 liquidityDelta) {
        return LiquidityFromAmounts.getLiquidityDeltaForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0);
    }

    function getLiquidityDeltaForAmount1(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 amount1
    ) external pure returns (uint256 liquidityDelta) {
        return LiquidityFromAmounts.getLiquidityDeltaForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1);
    }
}
