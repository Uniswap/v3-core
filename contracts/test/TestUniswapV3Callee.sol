// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../interfaces/IUniswapV3Callee.sol';
import '../interfaces/IUniswapV3Pair.sol';

contract TestUniswapV3Callee is IUniswapV3Callee {
    event SwapCallback(
        address msgSender,
        address sender,
        address recipient,
        int256 amount0Delta,
        int256 amount1Delta,
        bytes data
    );

    function swapCallback(
        address sender,
        address recipient,
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        emit SwapCallback(msg.sender, sender, recipient, amount0Delta, amount1Delta, data);

        if (amount0Delta < 0) {
            IERC20(IUniswapV3Pair(msg.sender).token0()).transfer(msg.sender, uint256(-amount0Delta));
        } else {
            require(
                IERC20(IUniswapV3Pair(msg.sender).token0()).balanceOf(recipient) >= uint256(amount0Delta),
                'recipient did not receive enough token0'
            );
        }
        if (amount1Delta < 0) {
            IERC20(IUniswapV3Pair(msg.sender).token1()).transfer(msg.sender, uint256(-amount1Delta));
        } else {
            require(
                IERC20(IUniswapV3Pair(msg.sender).token1()).balanceOf(recipient) >= uint256(amount1Delta),
                'recipient did not receive enough token1'
            );
        }
    }

    event MintCallback(
        address msgSender,
        address sender,
        address recipient,
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes data
    );

    function mintCallback(
        address sender,
        address recipient,
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        emit MintCallback(msg.sender, sender, recipient, amount0Owed, amount1Owed, data);
        if (amount0Owed > 0) IERC20(IUniswapV3Pair(msg.sender).token0()).transfer(msg.sender, uint256(amount0Owed));
        if (amount1Owed > 0) IERC20(IUniswapV3Pair(msg.sender).token1()).transfer(msg.sender, uint256(amount1Owed));
    }
}
