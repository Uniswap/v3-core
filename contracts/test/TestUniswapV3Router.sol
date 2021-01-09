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
    
    function swapAForC( 
        address [] memory pairs,
        uint256 amount1Out,
        address recipient
    ) public {
        console.log('starting swapAForC');
        IUniswapV3Pair(pairs[1]).swap(true, -amount1Out.toInt256(), 0, recipient, abi.encode(pairs, recipient)); //swap 0 for exact 1 (B for exact C)
    }

    function _swapAForExactB( 
        address [] memory pairs,
        int256 amount1Out,
        address recipient
    ) internal {
        console.log('starting second swap');
        IUniswapV3Pair(pairs[0]).swap(true, -amount1Out, 0, pairs[1], abi.encode(pairs[0], recipient)); //swap 0 for exact 1
                                                                                                        // possible to slice array for last position, then adjust towards zero by one instance on each internal callback, and as a result pass a arbitrary length of pairs for >3 token multihop?
    }

    //@dev  executes 2nd swap if there are more than one abi.encoded pair address's in call, pays off first if there is 1 remaining.

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public override {
        console.log('inside swap callback! :)');
        emit SwapCallback(amount0Delta, amount1Delta);

        (address[] memory pairs, address recipient) = abi.decode(data, (address [], address));
  
        if (pairs.length > 0) {
            _swapAForExactB(pairs, amount0Delta, recipient);

        } else if (pairs.length == 0) {
            IERC20(IUniswapV3Pair(msg.sender).token0()).transferFrom(recipient, pairs[0], uint256(-amount0Delta));

        } else {
            revert();
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



