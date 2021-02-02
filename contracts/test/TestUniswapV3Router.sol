// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/SafeCast.sol';
import '../libraries/SqrtTickMath.sol';

import '../interfaces/IERC20Minimal.sol';
import '../interfaces/callback/IUniswapV3SwapCallback.sol';
import '../interfaces/IUniswapV3Pair.sol';

contract TestUniswapV3Router is IUniswapV3SwapCallback {
    using SafeCast for uint256;

    // flash swaps for an exact amount of token0 in the output pair
    function swapForExact0Multi(
        address recipient,
        address pairInput,
        address pairOutput,
        uint256 amount0Out
    ) external {
        address[] memory pairs = new address[](1);
        pairs[0] = pairInput;
        IUniswapV3Pair(pairOutput).swap(
            recipient,
            false,
            -amount0Out.toInt256(),
            SqrtTickMath.MAX_SQRT_RATIO - 1,
            abi.encode(pairs, msg.sender)
        );
    }

    // flash swaps for an exact amount of token1 in the output pair
    function swapForExact1Multi(
        address recipient,
        address pairInput,
        address pairOutput,
        uint256 amount1Out
    ) external {
        address[] memory pairs = new address[](1);
        pairs[0] = pairInput;
        IUniswapV3Pair(pairOutput).swap(
            recipient,
            true,
            -amount1Out.toInt256(),
            SqrtTickMath.MIN_SQRT_RATIO + 1,
            abi.encode(pairs, msg.sender)
        );
    }

    event SwapCallback(int256 amount0Delta, int256 amount1Delta);

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public override {
        emit SwapCallback(amount0Delta, amount1Delta);

        (address[] memory pairs, address payer) = abi.decode(data, (address[], address));

        if (pairs.length == 1) {
            // get the address and amount of the token that we need to pay
            address tokenToBePaid =
                amount0Delta > 0 ? IUniswapV3Pair(msg.sender).token0() : IUniswapV3Pair(msg.sender).token1();
            int256 amountToBePaid = amount0Delta > 0 ? amount0Delta : amount1Delta;

            bool zeroForOne = tokenToBePaid == IUniswapV3Pair(pairs[0]).token1();
            IUniswapV3Pair(pairs[0]).swap(
                msg.sender,
                zeroForOne,
                -amountToBePaid,
                zeroForOne ? SqrtTickMath.MIN_SQRT_RATIO + 1 : SqrtTickMath.MAX_SQRT_RATIO - 1,
                abi.encode(new address[](0), payer)
            );
        } else {
            if (amount0Delta > 0) {
                IERC20Minimal(IUniswapV3Pair(msg.sender).token0()).transferFrom(
                    payer,
                    msg.sender,
                    uint256(amount0Delta)
                );
            } else {
                IERC20Minimal(IUniswapV3Pair(msg.sender).token1()).transferFrom(
                    payer,
                    msg.sender,
                    uint256(amount1Delta)
                );
            }
        }
    }
}
