// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../interfaces/ILCP20Minimal.sol';

import '../libraries/SafeCast.sol';
import '../libraries/TickMath.sol';

import '../interfaces/callback/ILeChainMintCallback.sol';
import '../interfaces/callback/ILeChainSwapCallback.sol';
import '../interfaces/callback/ILeChainFlashCallback.sol';

import '../interfaces/ILeChainPool.sol';

contract TestLeChainCallee is ILeChainMintCallback, ILeChainSwapCallback, ILeChainFlashCallback {
    using SafeCast for uint256;

    function swapExact0For1(
        address pool,
        uint256 amount0In,
        address recipient,
        uint160 sqrtPriceLimitX96
    ) external {
        ILeChainPool(pool).swap(recipient, true, amount0In.toInt256(), sqrtPriceLimitX96, abi.encode(msg.sender));
    }

    function swap0ForExact1(
        address pool,
        uint256 amount1Out,
        address recipient,
        uint160 sqrtPriceLimitX96
    ) external {
        ILeChainPool(pool).swap(recipient, true, -amount1Out.toInt256(), sqrtPriceLimitX96, abi.encode(msg.sender));
    }

    function swapExact1For0(
        address pool,
        uint256 amount1In,
        address recipient,
        uint160 sqrtPriceLimitX96
    ) external {
        ILeChainPool(pool).swap(recipient, false, amount1In.toInt256(), sqrtPriceLimitX96, abi.encode(msg.sender));
    }

    function swap1ForExact0(
        address pool,
        uint256 amount0Out,
        address recipient,
        uint160 sqrtPriceLimitX96
    ) external {
        ILeChainPool(pool).swap(recipient, false, -amount0Out.toInt256(), sqrtPriceLimitX96, abi.encode(msg.sender));
    }

    function swapToLowerSqrtPrice(
        address pool,
        uint160 sqrtPriceX96,
        address recipient
    ) external {
        ILeChainPool(pool).swap(recipient, true, type(int256).max, sqrtPriceX96, abi.encode(msg.sender));
    }

    function swapToHigherSqrtPrice(
        address pool,
        uint160 sqrtPriceX96,
        address recipient
    ) external {
        ILeChainPool(pool).swap(recipient, false, type(int256).max, sqrtPriceX96, abi.encode(msg.sender));
    }

    event SwapCallback(int256 amount0Delta, int256 amount1Delta);

    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        address sender = abi.decode(data, (address));

        emit SwapCallback(amount0Delta, amount1Delta);

        if (amount0Delta > 0) {
            ILCP20Minimal(ILeChainPool(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            ILCP20Minimal(ILeChainPool(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(amount1Delta));
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
    ) external {
        ILeChainPool(pool).mint(recipient, tickLower, tickUpper, amount, abi.encode(msg.sender));
    }

    event MintCallback(uint256 amount0Owed, uint256 amount1Owed);

    function mintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        address sender = abi.decode(data, (address));

        emit MintCallback(amount0Owed, amount1Owed);
        if (amount0Owed > 0)
            ILCP20Minimal(ILeChainPool(msg.sender).token0()).transferFrom(sender, msg.sender, amount0Owed);
        if (amount1Owed > 0)
            ILCP20Minimal(ILeChainPool(msg.sender).token1()).transferFrom(sender, msg.sender, amount1Owed);
    }

    event FlashCallback(uint256 fee0, uint256 fee1);

    function flash(
        address pool,
        address recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 pay0,
        uint256 pay1
    ) external {
        ILeChainPool(pool).flash(recipient, amount0, amount1, abi.encode(msg.sender, pay0, pay1));
    }

    function flashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        emit FlashCallback(fee0, fee1);

        (address sender, uint256 pay0, uint256 pay1) = abi.decode(data, (address, uint256, uint256));

        if (pay0 > 0) ILCP20Minimal(ILeChainPool(msg.sender).token0()).transferFrom(sender, msg.sender, pay0);
        if (pay1 > 0) ILCP20Minimal(ILeChainPool(msg.sender).token1()).transferFrom(sender, msg.sender, pay1);
    }
}
