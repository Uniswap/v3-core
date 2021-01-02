// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV3MintCallback {
    // callback sent to the caller of the mint method to collect payment
    function uniswapV3MintCallback(
        int256 amount0Owed,
        int256 amount1Owed,
        bytes calldata data
    ) external;
}
