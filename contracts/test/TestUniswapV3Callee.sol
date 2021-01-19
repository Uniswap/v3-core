// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../interfaces/IERC20.sol';

import '../libraries/SafeCast.sol';

import '../interfaces/callback/IUniswapV3MintCallback.sol';
import '../interfaces/callback/IUniswapV3SwapCallback.sol';
import '../interfaces/callback/IUniswapV3FlashCallback.sol';

import '../interfaces/IUniswapV3Pair.sol';

contract TestUniswapV3Callee is IUniswapV3MintCallback, IUniswapV3SwapCallback, IUniswapV3FlashCallback {
    using SafeCast for uint256;

    function swapExact0For1(
        address pair,
        uint256 amount0In,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(recipient, true, amount0In.toInt256(), 0, abi.encode(msg.sender));
    }

    function swap0ForExact1(
        address pair,
        uint256 amount1Out,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(recipient, true, -amount1Out.toInt256(), 0, abi.encode(msg.sender));
    }

    function swapExact1For0(
        address pair,
        uint256 amount1In,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(recipient, false, amount1In.toInt256(), uint160(-1), abi.encode(msg.sender));
    }

    function swap1ForExact0(
        address pair,
        uint256 amount0Out,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(recipient, false, -amount0Out.toInt256(), uint160(-1), abi.encode(msg.sender));
    }

    function swapToLowerSqrtPrice(
        address pair,
        uint160 sqrtPriceX96,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(
            recipient,
            true,
            int256(2**255 - 1), // max int256
            sqrtPriceX96,
            abi.encode(msg.sender)
        );
    }

    function swapToHigherSqrtPrice(
        address pair,
        uint160 sqrtPriceX96,
        address recipient
    ) external {
        // in the 0 for 1 case, we run into overflow in getNextSqrtPriceFromAmount1RoundingDown if this is not true:
        // amountSpecified < (2**160 - sqrtQ + 1) * l / 2**96
        // the amountSpecified below always satisfies this
        IUniswapV3Pair(pair).swap(
            recipient,
            false,
            int256((2**160 - sqrtPriceX96 + 1) / 2**96 - 1),
            sqrtPriceX96,
            abi.encode(msg.sender)
        );
    }

    event SwapCallback(int256 amount0Delta, int256 amount1Delta);

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        address sender = abi.decode(data, (address));

        emit SwapCallback(amount0Delta, amount1Delta);

        if (amount0Delta > 0) {
            IERC20(IUniswapV3Pair(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(amount0Delta));
        } else {
            // we know amount1Delta :> 0
            IERC20(IUniswapV3Pair(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(amount1Delta));
        }
    }

    function mint(
        address pair,
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external {
        IUniswapV3Pair(pair).mint(recipient, tickLower, tickUpper, amount, abi.encode(msg.sender));
    }

    event MintCallback(uint256 amount0Owed, uint256 amount1Owed);

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        address sender = abi.decode(data, (address));

        emit MintCallback(amount0Owed, amount1Owed);
        if (amount0Owed > 0) IERC20(IUniswapV3Pair(msg.sender).token0()).transferFrom(sender, msg.sender, amount0Owed);
        if (amount1Owed > 0) IERC20(IUniswapV3Pair(msg.sender).token1()).transferFrom(sender, msg.sender, amount1Owed);
    }

    event FlashCallback(uint256 fee0, uint256 fee1);

    function flash(
        address pair,
        address recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 pay0,
        uint256 pay1
    ) external {
        IUniswapV3Pair(pair).flash(recipient, amount0, amount1, abi.encode(msg.sender, pay0, pay1));
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        emit FlashCallback(fee0, fee1);

        (address sender, uint256 pay0, uint256 pay1) = abi.decode(data, (address, uint256, uint256));

        if (pay0 > 0) IERC20(IUniswapV3Pair(msg.sender).token0()).transferFrom(sender, msg.sender, pay0);
        if (pay1 > 0) IERC20(IUniswapV3Pair(msg.sender).token1()).transferFrom(sender, msg.sender, pay1);
    }
}
