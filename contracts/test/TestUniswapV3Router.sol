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

    function _swapBforC(
        address pair,
        int256 amount1Out,
        address recipient 
    ) internal {
        IUniswapV3Pair(pair).swap(true, -amount1Out, pair, abi.encode(msg.sender, pair));
    }

    function swapAforC(
        uint256 amount1Out,
        address recipient,
        address firstPair,
        address secondPair
    ) public {
        IUniswapV3Pair(secondPair).swap(true, -amount1Out.toInt256(), recipient, abi.encode(msg.sender, firstPair, secondPair)); 
    }

    event SwapCallback(int256 amount0Delta, int256 amount1Delta);

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public override {
        emit SwapCallback(amount0Delta, amount1Delta);

        //@dev  executes 2nd swap if there are three abi.encoded parameters in call, pays back first if there are two.

         abi.decode(data, ()).length >= (length of three parameters) ? 
         (address sender, address firstPair, address secondPair) = abi.decode(data, (address, address, address));
          _swapBforC(firstPair, amount0Delta, secondPair) :  

          (address sender, address firstPair) = abi.decode(data, (address, address));  
          IERC20(IUniswapV3Pair(msg.sender).token0()).transferFrom(sender, firstPair, uint256(-amount0Delta));
            
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