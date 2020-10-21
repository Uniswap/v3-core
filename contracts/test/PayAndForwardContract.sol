// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../interfaces/IUniswapV3Callee.sol';
import '../interfaces/IUniswapV3Pair.sol';

// used as a target in swaps
// forwards the output token to the swapper
// sends the input amount of the input token back to the pair
contract PayAndForwardContract is IUniswapV3Callee {
    uint256 public immutable inputAmount;
    address public immutable recipient;

    constructor(uint256 inputAmount_, address recipient_) public {
        inputAmount = inputAmount_;
        recipient = recipient_;
    }

    function uniswapV3Call(
        address,
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external override {
        (address inputToken, address outputToken, uint256 amountReceived) = amount0 > 0
            ? (IUniswapV3Pair(msg.sender).token1(), IUniswapV3Pair(msg.sender).token0(), amount0)
            : (IUniswapV3Pair(msg.sender).token0(), IUniswapV3Pair(msg.sender).token1(), amount1);

        assert(amountReceived > 0);

        IERC20(inputToken).transfer(msg.sender, inputAmount);
        IERC20(outputToken).transfer(recipient, amountReceived);
    }
}
