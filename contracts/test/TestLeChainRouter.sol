// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/SafeCast.sol';
import '../libraries/TickMath.sol';

import '../interfaces/ILCP20Minimal.sol';
import '../interfaces/callback/ILeChainSwapCallback.sol';
import '../interfaces/ILeChainPool.sol';

contract TestLeChainRouter is ILeChainSwapCallback {
    using SafeCast for uint256;

    // flash swaps for an exact amount of token0 in the output pool
    function swapForExact0Multi(
        address recipient,
        address poolInput,
        address poolOutput,
        uint256 amount0Out
    ) external {
        address[] memory pools = new address[](1);
        pools[0] = poolInput;
        ILeChainPool(poolOutput).swap(
            recipient,
            false,
            -amount0Out.toInt256(),
            TickMath.MAX_SQRT_RATIO - 1,
            abi.encode(pools, msg.sender)
        );
    }

    // flash swaps for an exact amount of token1 in the output pool
    function swapForExact1Multi(
        address recipient,
        address poolInput,
        address poolOutput,
        uint256 amount1Out
    ) external {
        address[] memory pools = new address[](1);
        pools[0] = poolInput;
        ILeChainPool(poolOutput).swap(
            recipient,
            true,
            -amount1Out.toInt256(),
            TickMath.MIN_SQRT_RATIO + 1,
            abi.encode(pools, msg.sender)
        );
    }

    event SwapCallback(int256 amount0Delta, int256 amount1Delta);

    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public override {
        emit SwapCallback(amount0Delta, amount1Delta);

        (address[] memory pools, address payer) = abi.decode(data, (address[], address));

        if (pools.length == 1) {
            // get the address and amount of the token that we need to pay
            address tokenToBePaid =
                amount0Delta > 0 ? ILeChainPool(msg.sender).token0() : ILeChainPool(msg.sender).token1();
            int256 amountToBePaid = amount0Delta > 0 ? amount0Delta : amount1Delta;

            bool zeroForOne = tokenToBePaid == ILeChainPool(pools[0]).token1();
            ILeChainPool(pools[0]).swap(
                msg.sender,
                zeroForOne,
                -amountToBePaid,
                zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
                abi.encode(new address[](0), payer)
            );
        } else {
            if (amount0Delta > 0) {
                ILCP20Minimal(ILeChainPool(msg.sender).token0()).transferFrom(
                    payer,
                    msg.sender,
                    uint256(amount0Delta)
                );
            } else {
                ILCP20Minimal(ILeChainPool(msg.sender).token1()).transferFrom(
                    payer,
                    msg.sender,
                    uint256(amount1Delta)
                );
            }
        }
    }
}
