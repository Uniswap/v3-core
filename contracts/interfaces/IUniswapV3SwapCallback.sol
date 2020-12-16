// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV3SwapCallback {
    // callback sent to the caller of a swap method
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta) external;
}
