// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV3Callee {
    // called on the payer of a swap
    function swapCallback(
        address sender,
        address recipient,
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}
