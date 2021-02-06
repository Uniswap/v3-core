// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/SafeCast.sol';
import '../libraries/TickMath.sol';
import "hardhat/console.sol";


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
            TickMath.MAX_SQRT_RATIO - 1,
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
            TickMath.MIN_SQRT_RATIO + 1,
            abi.encode(pairs, msg.sender)
        );
    }
    // flash swaps for an exact amount of token1 in the output pair
    function swapForExact1Endless(
        address recipient,
        address[] memory pairsList,
        uint256 amount1Out
    ) external {
        console.log('start endless');
        address[] memory pairs = new address[](pairsList.length);
        pairs = pairsList;
        uint numRemainingSwaps = pairsList.length;
        numRemainingSwaps--;
        console.log('initiating first swap');
        IUniswapV3Pair(pairs[numRemainingSwaps]).swap(
            recipient,
            true,
            -amount1Out.toInt256(),
            TickMath.MIN_SQRT_RATIO + 1,
            abi.encode(pairs, msg.sender)
        );
    }

    event SwapCallback(int256 amount0Delta, int256 amount1Delta);

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public override {
        console.log('inside swap callback');
        emit SwapCallback(amount0Delta, amount1Delta);

        (address[] memory pairs, address payer) = abi.decode(data, (address[], address));

        uint numRemainingSwaps = pairs.length;

        //for(remainingSwaps = 0; remainingSwaps < pairs.length; remainingSwaps++) {}
           
           numRemainingSwaps--;

        if (numRemainingSwaps >= 1) {
            console.log('initiating next swap');
            // get the address and amount of the token that we need to pay
            //numRemainingSwaps--;

            address[] memory remainingPairs = new address[](numRemainingSwaps);

            remainingPairs = pairs; // cuts off last element?


            address tokenToBePaid =
                amount0Delta > 0 ? IUniswapV3Pair(msg.sender).token0() : IUniswapV3Pair(msg.sender).token1();
            int256 amountToBePaid = 
                amount0Delta > 0 ? amount0Delta : amount1Delta;
            bool zeroForOne = 
                tokenToBePaid == IUniswapV3Pair(msg.sender).token1();

            IUniswapV3Pair(remainingPairs[numRemainingSwaps]).swap(
                msg.sender,
                zeroForOne,
                -amountToBePaid,
                zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
                abi.encode(remainingPairs = new address[](numRemainingSwaps), payer)
            );
        } else {
            if (amount0Delta > 0) {
                console.log('initiating final payback in token0');
                IERC20Minimal(IUniswapV3Pair(msg.sender).token0()).transferFrom(
                    payer,
                    msg.sender,
                    uint256(amount0Delta)
                );
            } else {
                console.log('initiating final payback in token1');
                IERC20Minimal(IUniswapV3Pair(msg.sender).token1()).transferFrom(
                    payer,
                    msg.sender,
                    uint256(amount1Delta)
                );
            }
        }
    }
}
