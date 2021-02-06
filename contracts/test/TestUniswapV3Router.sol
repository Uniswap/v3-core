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
    // flash swaps for an exact amount of token0 in the final pair in the pair array
    // accepts an arbitrary number of pairs to swap through
    function swapForExact0Endless(
        address recipient,
        address[] memory pairs,
        uint256 amount0Out
    ) external {
        console.log('start endless for exact 0');
        uint numRemainingSwaps = pairs.length;
        numRemainingSwaps--;
        console.log('initiating first swap');
        IUniswapV3Pair(pairs[numRemainingSwaps]).swap(
            recipient,
            false,
            -amount0Out.toInt256(),
            TickMath.MAX_SQRT_RATIO - 1,
            abi.encode(numRemainingSwaps, pairs, msg.sender)
        );
    }    
    // flash swaps for an exact amount of token1 in the final pair in the pair array
    // accepts an arbitrary number of pairs to swap through
    function swapForExact1Endless(
        address recipient,
        address[] memory pairs,
        uint256 amount1Out
    ) external {
        console.log('start endless for exact 1');
        uint numRemainingSwaps = pairs.length;
        numRemainingSwaps--;
        console.log('initiating first swap');
        IUniswapV3Pair(pairs[numRemainingSwaps]).swap( 
            recipient,
            true,
            -amount1Out.toInt256(),
            TickMath.MIN_SQRT_RATIO + 1,
            abi.encode((numRemainingSwaps), pairs, msg.sender)
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

        (uint numRemainingSwaps, address[] memory pairs, address payer) = abi.decode(data, (uint, address[], address));

        if (numRemainingSwaps >= 1) {
            console.log('initiating next swap');
            numRemainingSwaps--;
            // get the address and amount of the token that we need to pay
            address tokenToBePaid =
                amount0Delta > 0 ? IUniswapV3Pair(msg.sender).token0() : IUniswapV3Pair(msg.sender).token1();
            int256 amountToBePaid = 
                amount0Delta > 0 ? amount0Delta : amount1Delta;
            bool zeroForOne = 
                tokenToBePaid == IUniswapV3Pair(pairs[numRemainingSwaps]).token1();


            IUniswapV3Pair(pairs[numRemainingSwaps]).swap(
                msg.sender,
                zeroForOne,
                -amountToBePaid,
                zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
                abi.encode(numRemainingSwaps, pairs, payer)
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
