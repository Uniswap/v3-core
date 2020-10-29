// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '../interfaces/IUniswapV3Callee.sol';

contract TestUniswapV3Callee is IUniswapV3Callee {
    event Callback(address msgSender, address sender, uint256 amount0, uint256 amount1, bytes data);

    function uniswapV3Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        emit Callback(msg.sender, sender, amount0, amount1, data);
    }
}
