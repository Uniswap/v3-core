// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import 'hardhat/console.sol';

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../libraries/SafeCast.sol';

import '../interfaces/IUniswapV3MintCallback.sol';
import '../interfaces/IUniswapV3SwapCallback.sol';
import '../interfaces/IUniswapV3Pair.sol';

contract TestUniswapV3Router is IUniswapV3SwapCallback {
    using SafeCast for uint256;

    function swapExact0For1(
        address pair,
        uint256 amount0In,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(true, amount0In.toInt256(), 0, recipient, abi.encode(msg.sender));
    }

    function swap0ForExact1(
        address pair,
        uint256 amount1Out,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(true, -amount1Out.toInt256(), 0, recipient, abi.encode(msg.sender));
    }

    function swapExact1For0(
        address pair,
        uint256 amount1In,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(false, amount1In.toInt256(), uint160(-1), recipient, abi.encode(msg.sender));
    }

    function swap1ForExact0(
        address pair,
        uint256 amount0Out,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(false, -amount0Out.toInt256(), uint160(-1), recipient, abi.encode(msg.sender));
    }

    function swapToLowerSqrtPrice(
        address pair,
        uint160 sqrtPrice,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(
            true,
            int256(2**255 - 1), // max int256
            sqrtPrice,
            recipient,
            abi.encode(msg.sender)
        );
    }

    function swapToHigherSqrtPrice(
        address pair,
        uint160 sqrtPrice,
        address recipient
    ) external {
        // in the 0 for 1 case, we run into overflow in getNextPriceFromAmount1RoundingDown if this is not true:
        // amountSpecified < (2**160 - sqrtQ + 1) * l / 2**96
        // the amountSpecified below always satisfies this
        IUniswapV3Pair(pair).swap(
            false,
            int256((2**160 - sqrtPrice + 1) / 2**96 - 1),
            sqrtPrice,
            recipient,
            abi.encode(msg.sender)
        );
    }
    event SwapCallback(int256 amount0Delta, int256 amount1Delta);
    
    // swaps 0 for exact 2 in series of 0forExact1 steps, in reverse order. 
    function swap0ForExact2( 
        address [] memory pairs,
        uint256 amount1Out,
        address recipient,
        bool finished
    ) public {
        console.log('starting swap0ForExact2');
        IUniswapV3Pair(pairs[1]).swap(true, -amount1Out.toInt256(), 0, recipient, abi.encode(pairs, recipient, (finished = false)));   //swap 0 for exact 1     
    }

     function swap2ForExact0( 
        address [] memory pairs,
        uint256 amount0Out,
        address recipient,
        bool finished
    ) public {
        console.log('starting swap2ForExact0');
        IUniswapV3Pair(pairs[0 ]).swap(false, -amount0Out.toInt256(), uint160(-1), recipient, abi.encode(pairs, recipient, (finished = false)));   //swap 1 for exact 0    
    }

    function _multiSwapCallback( 
        address [] memory pairs,
        int256 amount1Out,
        int256 amount0Out,
        address recipient,
        bool finished
    ) internal {
        
        console.log('starting second swap'); 
        (amount1Out > 0) ? 
       // console.log('second swap 0 for 1'); 
        IUniswapV3Pair(pairs[0]).swap(true, -amount1Out, 0, pairs[1], abi.encode(pairs, recipient, (finished = true))) :
       // console.log('second swap 1 for 0'); 
        IUniswapV3Pair(pairs[1]).swap(false, -amount0Out, uint160(-1), pairs[0], abi.encode(pairs, recipient, (finished = true)));

    }

    // executes 2nd swap if bool finished == false, pays off first if finished == true.
    // possible to explore swap stage logic based on shift operators directed towards pair address array.

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public override {
        console.log('inside swap callback! :)');
        
        emit SwapCallback(amount0Delta, amount1Delta);

        (address[] memory pairs, address recipient, bool finished) = abi.decode(data, (address [], address, bool));

        console.log('abi decoded');

        if (finished == false) {
            console.log('if finished == false, go to second swap');
            if (amount0Delta > 0) {
                console.log('0Delta > 0, go to second swap');
                _multiSwapCallback(pairs, amount0Delta, 0, recipient, finished);
        }   else if (amount1Delta > 0) {
                console.log('1Delta > 0, go to second swap');
                _multiSwapCallback(pairs, 0, amount1Delta, recipient, finished);
        }

        } else if (finished == true) {
            console.log('finished == true, repay first swap');
            if (amount0Delta > 0){
                console.log('0Delta > 0, repay first swap');
                IERC20(IUniswapV3Pair(msg.sender).token0()).transferFrom(recipient, pairs[0], uint256(amount0Delta)); // transfer from wallet addres token0 to pay back swap
        }   else if (amount1Delta > 0){
                console.log('1Delta > 0, repay first swap');
                IERC20(IUniswapV3Pair(msg.sender).token1()).transferFrom(recipient, pairs[1], uint256(amount1Delta)); // transfer from wallet addres token0 to pay back swap
        }
          console.log('finished!');
        }       
    }

    function initialize(address pair, uint160 sqrtPrice) external {
        IUniswapV3Pair(pair).initialize(sqrtPrice, abi.encode(msg.sender));
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
    ) external {
        address sender = abi.decode(data, (address));

        emit MintCallback(amount0Owed, amount1Owed);
        if (amount0Owed > 0)
            IERC20(IUniswapV3Pair(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(amount0Owed));
        if (amount1Owed > 0)
            IERC20(IUniswapV3Pair(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(amount1Owed));
    }
}



