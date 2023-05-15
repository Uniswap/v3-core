// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../interfaces/ILCP20Minimal.sol';

import '../interfaces/callback/ILeChainSwapCallback.sol';
import '../interfaces/ILeChainPool.sol';

contract LeChainPoolSwapTest is ILeChainSwapCallback {
    int256 private _amount0Delta;
    int256 private _amount1Delta;

    function getSwapResult(
        address pool,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96
    )
        external
        returns (
            int256 amount0Delta,
            int256 amount1Delta,
            uint160 nextSqrtRatio
        )
    {
        (amount0Delta, amount1Delta) = ILeChainPool(pool).swap(
            address(0),
            zeroForOne,
            amountSpecified,
            sqrtPriceLimitX96,
            abi.encode(msg.sender)
        );

        (nextSqrtRatio, , , , , , ) = ILeChainPool(pool).slot0();
    }

    function swapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        address sender = abi.decode(data, (address));

        if (amount0Delta > 0) {
            ILCP20Minimal(ILeChainPool(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            ILCP20Minimal(ILeChainPool(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(amount1Delta));
        }
    }
}
