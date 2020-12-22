// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../libraries/SafeCast.sol';

import '../interfaces/IUniswapV3MintCallback.sol';
import '../interfaces/IUniswapV3SwapCallback.sol';
import '../interfaces/IUniswapV3Pair.sol';

contract TestUniswapV3Callee is IUniswapV3MintCallback, IUniswapV3SwapCallback {
    using SafeCast for uint256;

    function swapExact0For1(
        address pair,
        uint256 amount0In,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(true, amount0In.toInt256(), recipient, abi.encode(msg.sender));
    }

}

/*
 allows exact output swaps from A -> B -> C, where the steps look like:

initiate an exact output swap on the BxC pair, resulting in a transfer of C from BxC to user
within the (outer) swap callback, initiate an exact swap on AxB, resulting in a transfer of B to BxC
in the inner swap callback, resolve by triggering a transfer of A from user to AxB (via transferFrom)
*/