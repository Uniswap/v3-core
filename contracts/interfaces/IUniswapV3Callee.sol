// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV3Callee {
    // callback sent to the caller of a swap method
    function swapCallback(int256 amount0Delta, int256 amount1Delta) external;

    // callback sent to the caller of the mint method to collect payment
    function mintCallback(uint256 amount0Owed, uint256 amount1Owed) external;
}
