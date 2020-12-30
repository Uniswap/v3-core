// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '../libraries/SafeCast.sol';

import '../interfaces/IUniswapV3MintCallback.sol';
import '../interfaces/IUniswapV3SwapCallback.sol';
import '../interfaces/IUniswapV3Pair.sol';



abstract contract TestUniswapV3Router is IUniswapV3MintCallback, IUniswapV3SwapCallback {
    using SafeCast for uint256;
    using SafeCast for int256;


    function swapExact0For1(
        address pair,
        uint256 amount0In,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(true, amount0In.toInt256(), recipient, abi.encode(msg.sender));
    }

    function swap0ForExact1(
        address pair,
        uint256 amount1Out,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(true, -amount1Out.toInt256(), recipient, abi.encode(msg.sender));
    }

    function swapExact1For0(
        address pair,
        uint256 amount1In,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(false, amount1In.toInt256(), recipient, abi.encode(msg.sender));
    }

    function swap1ForExact0(
        address pair,
        uint256 amount0Out,
        address recipient
    ) external {
        IUniswapV3Pair(pair).swap(false, -amount0Out.toInt256(), recipient, abi.encode(msg.sender));
    }


/*
 allows exact output swaps from A -> B -> C, where the steps look like:

initiate an exact output swap on the BxC pair, resulting in a transfer of C from BxC to user
within the (outer) swap callback, initiate an exact swap on AxB, resulting in a transfer of B to BxC
in the inner swap callback, resolve by triggering a transfer of A from user to AxB (via transferFrom)
*/
    function swapAforC(
        uint256 amount1Out,
        address recipient,
        address [] memory pairs
    ) public {
        IUniswapV3Pair(pairs[1]).swap(true, -amount1Out.toInt256(), recipient, abi.encode(recipient, pairs)); 
    }


    function _swapBforExactC(
        int256 amount0In,
        address recipient,
        address [] memory pairs 
    ) internal {
  

        IUniswapV3Pair(pairs[0]).swap(true, amount0In, pairs[1], abi.encode(recipient, pairs[0]));
    }


    event SwapCallback(int256 amount0Delta, int256 amount1Delta);

    //@dev  executes 2nd swap if there are more than one abi.encoded pair address's in call, pays off first if there is 1 remaining.
    // recipient is available in callback but currently unused
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public override {
        
        emit SwapCallback(amount0Delta, amount1Delta);

        (address recipient, address[] memory pairs) = abi.decode(data, (address, address[]));
  
        if (pairs.length > 0) {
            _swapBforExactC(amount0Delta, recipient, pairs);

        } else if (pairs.length == 0) {
            IERC20(IUniswapV3Pair(msg.sender).token0()).transferFrom(msg.sender, pairs[0], uint256(-amount0Delta));

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
    ) external override {
        address sender = abi.decode(data, (address));

        emit MintCallback(amount0Owed, amount1Owed);
        if (amount0Owed > 0)
            IERC20(IUniswapV3Pair(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(amount0Owed));
        if (amount1Owed > 0)
            IERC20(IUniswapV3Pair(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(amount1Owed));
    }
}


/*
 allows exact output swaps from A -> B -> C, where the steps look like:

initiate an exact output swap on the BxC pair, resulting in a transfer of C from BxC to user
within the (outer) swap callback, initiate an exact swap on AxB, resulting in a transfer of B to BxC
in the inner swap callback, resolve by triggering a transfer of A from user to AxB (via transferFrom)
*/