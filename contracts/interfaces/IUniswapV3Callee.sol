// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.6.8;

interface IUniswapV3Callee {
    function uniswapV3Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
