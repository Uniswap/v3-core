// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../interfaces/IUniswapV3MintCallback.sol';
import '../interfaces/IUniswapV3SwapCallback.sol';
import '../interfaces/IUniswapV3Pair.sol';

contract TestUniswapV3Callee is IUniswapV3MintCallback, IUniswapV3SwapCallback {
    address sender;

    function swap0For1(
        address pair,
        uint256 amount0In,
        address recipient
    ) external {
        require(sender == address(0));

        sender = msg.sender;
        IUniswapV3Pair(pair).swap0For1(amount0In, recipient);
        sender = address(0);
    }

    function swap1For0(
        address pair,
        uint256 amount1In,
        address recipient
    ) external {
        require(sender == address(0));

        sender = msg.sender;
        IUniswapV3Pair(pair).swap1For0(amount1In, recipient);
        sender = address(0);
    }

    event SwapCallback(int256 amount0Delta, int256 amount1Delta);

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta) external override {
        require(sender != address(0));

        emit SwapCallback(amount0Delta, amount1Delta);

        if (amount0Delta < 0) {
            IERC20(IUniswapV3Pair(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(-amount0Delta));
        }
        if (amount1Delta < 0) {
            IERC20(IUniswapV3Pair(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(-amount1Delta));
        }
    }

    function initialize(address pair, uint160 sqrtPrice) external {
        require(sender == address(0));

        sender = msg.sender;
        IUniswapV3Pair(pair).initialize(sqrtPrice);
        sender = address(0);
    }

    function mint(
        address pair,
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external {
        require(sender == address(0));

        sender = msg.sender;
        IUniswapV3Pair(pair).mint(recipient, tickLower, tickUpper, amount);
        sender = address(0);
    }

    event MintCallback(uint256 amount0Owed, uint256 amount1Owed);

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed) external override {
        require(sender != address(0));

        emit MintCallback(amount0Owed, amount1Owed);
        if (amount0Owed > 0)
            IERC20(IUniswapV3Pair(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(amount0Owed));
        if (amount1Owed > 0)
            IERC20(IUniswapV3Pair(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(amount1Owed));
    }
}
