// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../interfaces/ILCP20Minimal.sol';

import '../interfaces/callback/ILeChainSwapCallback.sol';
import '../interfaces/ILeChainPool.sol';

contract TestLeChainSwapPay is ILeChainSwapCallback {
    function swap(
        address pool,
        address recipient,
        bool zeroForOne,
        uint160 sqrtPriceX96,
        int256 amountSpecified,
        uint256 pay0,
        uint256 pay1
    ) external {
        ILeChainPool(pool).swap(
            recipient,
            zeroForOne,
            amountSpecified,
            sqrtPriceX96,
            abi.encode(msg.sender, pay0, pay1)
        );
    }

    function swapCallback(
        int256,
        int256,
        bytes calldata data
    ) external override {
        (address sender, uint256 pay0, uint256 pay1) = abi.decode(data, (address, uint256, uint256));

        if (pay0 > 0) {
            ILCP20Minimal(ILeChainPool(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(pay0));
        } else if (pay1 > 0) {
            ILCP20Minimal(ILeChainPool(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(pay1));
        }
    }
}
