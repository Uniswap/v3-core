// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV3FlashCallback {
    function uniswapV3FlashCallback(
        address sender,
        uint256 amount0,
        uint256 fee0,
        uint256 amount1,
        uint256 fee1,
        bytes calldata
    ) external;
}
