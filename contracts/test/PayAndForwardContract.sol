// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../interfaces/IUniswapV3Callee.sol';
import '../interfaces/IUniswapV3Pair.sol';

// used as a target in swaps
// amount to pay and who to forward swap output to is encoded in data
contract PayAndForwardContract is IUniswapV3Callee {
    function swap0For1Callback(
        address,
        uint256 amount1Out,
        bytes calldata data
    ) external override {
        (uint256 inputAmount, address recipient) = abi.decode(data, (uint256, address));
        IERC20(IUniswapV3Pair(msg.sender).token0()).transfer(msg.sender, inputAmount);
        IERC20(IUniswapV3Pair(msg.sender).token1()).transfer(recipient, amount1Out);
    }

    function swap1For0Callback(
        address,
        uint256 amount0Out,
        bytes calldata data
    ) external override {
        (uint256 inputAmount, address recipient) = abi.decode(data, (uint256, address));
        IERC20(IUniswapV3Pair(msg.sender).token1()).transfer(msg.sender, inputAmount);
        IERC20(IUniswapV3Pair(msg.sender).token0()).transfer(recipient, amount0Out);
    }
}
