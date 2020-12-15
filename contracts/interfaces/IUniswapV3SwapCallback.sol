// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV3SwapCallback {
    // callback sent to the caller of a swap method
    function swapCallback(int256 amount0Delta, int256 amount1Delta) external;
}
