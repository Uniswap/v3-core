// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './interfaces/IERC20Minimal.sol';

import './libraries/SafeCast.sol';
import './libraries/TickMath.sol';

import './interfaces/callback/IUniswapV3MintCallback.sol';
import './interfaces/callback/IUniswapV3SwapCallback.sol';
import './interfaces/callback/IUniswapV3FlashCallback.sol';

import './interfaces/pool/IUniswapV3PoolActions.sol';
import './interfaces/pool/IUniswapV3PoolImmutables.sol';

contract TestUniswapV3Callee is IUniswapV3MintCallback, IUniswapV3SwapCallback, IUniswapV3FlashCallback {
    using SafeCast for uint256;

    // function swapExact0For1(
    //     address pool,
    //     uint256 amount0In,
    //     address recipient,
    //     uint160 sqrtPriceLimitX96
    // ) external {
    //     IUniswapV3PoolActions(pool).swap(recipient, true, amount0In.toInt256(), sqrtPriceLimitX96, msg.sender);
    // }

    function swap0ForExact1(
        address pool,
        uint256 amount1Out,
        address recipient,
        uint160 sqrtPriceLimitX96
    ) external returns (int, int) {
       return IUniswapV3PoolActions(pool).swap(recipient, true, -amount1Out.toInt256(), sqrtPriceLimitX96, msg.sender);
    }

    // function swapExact1For0(
    //     address pool,
    //     uint256 amount1In,
    //     address recipient,
    //     uint160 sqrtPriceLimitX96
    // ) external {
    //     IUniswapV3PoolActions(pool).swap(recipient, false, amount1In.toInt256(), sqrtPriceLimitX96, msg.sender);
    // }

    // function swap1ForExact0(
    //     address pool,
    //     uint256 amount0Out,
    //     address recipient,
    //     uint160 sqrtPriceLimitX96
    // ) external {
    //     IUniswapV3PoolActions(pool).swap(recipient, false, -amount0Out.toInt256(), sqrtPriceLimitX96, msg.sender);
    // }

    // function swapToLowerSqrtPrice(
    //     address pool,
    //     uint160 sqrtPriceX96,
    //     address recipient
    // ) external {
    //     IUniswapV3PoolActions(pool).swap(recipient, true, type(int256).max, sqrtPriceX96, msg.sender);
    // }

    // function swapToHigherSqrtPrice(
    //     address pool,
    //     uint160 sqrtPriceX96,
    //     address recipient
    // ) external {
    //     IUniswapV3PoolActions(pool).swap(recipient, false, type(int256).max, sqrtPriceX96, msg.sender);
    // }

    event SwapCallback(int256 amount0Delta, int256 amount1Delta);

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        address sender
    ) external override {
        // address sender = abi.decode(data, (address));

        emit SwapCallback(amount0Delta, amount1Delta);

        if (amount0Delta > 0) {
            IERC20Minimal(IUniswapV3PoolImmutables(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20Minimal(IUniswapV3PoolImmutables(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(amount1Delta));
        } else {
            // if both are not gt 0, both must be 0.
            assert(amount0Delta == 0 && amount1Delta == 0);
        }
    }

    function mint(
        address pool,
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1) {
        return IUniswapV3PoolActions(pool).mint(recipient, tickLower, tickUpper, amount, msg.sender);
    }

    event MintCallback(uint256 amount0Owed, uint256 amount1Owed);

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        address sender
    ) external override {
        // address sender = abi.decode(data, (address));

        emit MintCallback(amount0Owed, amount1Owed);
        if (amount0Owed > 0)
            IERC20Minimal(IUniswapV3PoolImmutables(msg.sender).token0()).transferFrom(sender, msg.sender, amount0Owed);
        if (amount1Owed > 0)
            IERC20Minimal(IUniswapV3PoolImmutables(msg.sender).token1()).transferFrom(sender, msg.sender, amount1Owed);
    }

    event FlashCallback(uint256 fee0, uint256 fee1);

    function flash(
        address pool,
        address recipient,
        uint256 amount0,
        uint256 amount1,
        address sender,
        uint256 pay0,
        uint256 pay1
    ) external {
        IUniswapV3PoolActions(pool).flash(recipient, amount0, amount1, sender, pay0, pay1);
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        address sender,
        uint256 pay0,
        uint256 pay1
    ) external override {
        emit FlashCallback(fee0, fee1);

        // (address sender, uint256 pay0, uint256 pay1) = abi.decode(data, (address, uint256, uint256));

        if (pay0 > 0) IERC20Minimal(IUniswapV3PoolImmutables(msg.sender).token0()).transferFrom(sender, msg.sender, pay0);
        if (pay1 > 0) IERC20Minimal(IUniswapV3PoolImmutables(msg.sender).token1()).transferFrom(sender, msg.sender, pay1);
    }
}
