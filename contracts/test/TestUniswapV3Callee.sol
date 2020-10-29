// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '../interfaces/IUniswapV3Callee.sol';

contract TestUniswapV3Callee is IUniswapV3Callee {
    event Swap0For1Callback(address msgSender, address sender, uint256 amount1Out, bytes data);

    function swap0For1Callback(
        address sender,
        uint256 amount1Out,
        bytes calldata data
    ) external override {
        emit Swap0For1Callback(msg.sender, sender, amount1Out, data);
    }

    event Swap1For0Callback(address msgSender, address sender, uint256 amount0Out, bytes data);

    function swap1For0Callback(
        address sender,
        uint256 amount0Out,
        bytes calldata data
    ) external override {
        emit Swap1For0Callback(msg.sender, sender, amount0Out, data);
    }
}
