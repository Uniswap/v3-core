// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.12;

import {Simulate} from '../libraries/Simulate.sol';

import {IUniswapV3Pool} from '../interfaces/IUniswapV3Pool.sol';

contract SimulateTest {
    function simulateSwap(
        IUniswapV3Pool pool,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96
    ) external view returns (int256 amount0, int256 amount1) {
        return Simulate.simulateSwap(pool, zeroForOne, amountSpecified, sqrtPriceLimitX96);
    }
}
