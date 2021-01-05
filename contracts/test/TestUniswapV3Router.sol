// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../libraries/SafeCast.sol';

import '../interfaces/IUniswapV3MintCallback.sol';
import '../interfaces/IUniswapV3SwapCallback.sol';
import '../interfaces/IUniswapV3Pair.sol';

abstract contract TestUniswapV3Router is IUniswapV3MintCallback, IUniswapV3SwapCallback {
    using SafeCast for uint256;
/*
 allows exact output swaps from A -> B -> C, where the steps look like:

initiate an exact output swap on the BxC pair, resulting in a transfer of C from BxC to user
within the (outer) swap callback, initiate an exact swap on AxB, resulting in a transfer of B to BxC
in the inner swap callback, resolve by triggering a transfer of A from user to AxB (via transferFrom)
*/
    event SwapCallback(int256 amount0Delta, int256 amount1Delta);
    
    function swapAForC( 
        address [] memory pairs,
        uint256 amount1Out,
        address recipient
    ) public {
        IUniswapV3Pair(pairs[1]).swap(true, -amount1Out.toInt256(), 0, recipient, abi.encode(pairs, recipient)); //swap 0 for exact 1 (B for exact C)
    }

    function _swapAForExactB( 
        address [] memory pairs,
        int256 amount1Out,
        address recipient
    ) internal {
        IUniswapV3Pair(pairs[0]).swap(true, -amount1Out, 0, pairs[1], abi.encode(pairs[0], recipient)); //swap 0 for exact 1
                                                                                                        // possible to slice array for last position, then adjust towards zero by one instance on each internal callback, and as a result pass a arbitrary length of pairs for >3 token multihop?
    }

    //@dev  executes 2nd swap if there are more than one abi.encoded pair address's in call, pays off first if there is 1 remaining.

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public override {
        
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

}
