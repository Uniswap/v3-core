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


    // swaps 0 for exact 1 arbitrary length multihop
    function swap0ForExact1Multi(
        address recipient,
        address[] memory pairs,
        uint256 amount1Out
    ) external {
        bool originZeroForOne = true;
        uint numRemainingSwaps = pairs.length - 1;
        IUniswapV3Pair(pairs[numRemainingSwaps]).swap( 
            recipient,
            true,
            -amount1Out.toInt256(),
            TickMath.MIN_SQRT_RATIO + 1,
            abi.encode(numRemainingSwaps, originZeroForOne, pairs, msg.sender)
        );
    }    
    
    // swaps 1 for exact 0 arbitrary length multihop
    function swap1ForExact0Multi(
        address recipient,
        address[] memory pairs,
        uint256 amount0Out
    ) external {
        uint numRemainingSwaps = pairs.length - 1;
        bool originZeroForOne = false;
        IUniswapV3Pair(pairs[numRemainingSwaps]).swap(
            recipient,
            false,
            -amount0Out.toInt256(),
            TickMath.MAX_SQRT_RATIO - 1,
            abi.encode(numRemainingSwaps, originZeroForOne, pairs, msg.sender)
        );
    }   

    // swaps 0 for exact 0 arbitrary length multihop
    function swap0ForExact0Multi(
        address recipient,
        address[] memory pairs,
        uint256 amount0Out
    ) external {
        bool originZeroForOne = true;
        uint numRemainingSwaps = pairs.length - 1;
        IUniswapV3Pair(pairs[numRemainingSwaps]).swap( 
            recipient,
            false,
            -amount0Out.toInt256(),
            TickMath.MAX_SQRT_RATIO - 1,
            abi.encode(numRemainingSwaps, originZeroForOne, pairs, msg.sender)
        );
    }    

    // swaps 1 for exact 1 arbitrary length multihop
    function swap1ForExact1Multi(
        address recipient,
        address[] memory pairs,
        uint256 amount1Out
    ) external {
        bool originZeroForOne = false;
        uint numRemainingSwaps = pairs.length - 1;
        IUniswapV3Pair(pairs[numRemainingSwaps]).swap( 
            recipient,
            true,
            -amount1Out.toInt256(),
            TickMath.MIN_SQRT_RATIO + 1,
            abi.encode(numRemainingSwaps, originZeroForOne, pairs, msg.sender)
        );
    }      
 
    event SwapCallback(int256 amount0Delta, int256 amount1Delta);

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public override {
        emit SwapCallback(amount0Delta, amount1Delta);

        (uint numRemainingSwaps, bool originZeroForOne, address[] memory pairs, address payer) = 
        abi.decode(data, (uint, bool, address[], address));

        if (numRemainingSwaps > 0) {
            numRemainingSwaps--;
            // get the address, amount, and direction of the token that we need to pay
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
                    abi.encode(numRemainingSwaps, originZeroForOne, pairs, payer)
            );
     } else {
            originZeroForOne ?
                IERC20Minimal(IUniswapV3Pair(msg.sender).token0()).transferFrom(
                    payer,
                    msg.sender,
                    uint256(amount0Delta)
                ) :
                IERC20Minimal(IUniswapV3Pair(msg.sender).token1()).transferFrom(
                    payer,
                    msg.sender,
                    uint256(amount1Delta)
                );
            
        }
    }
}
