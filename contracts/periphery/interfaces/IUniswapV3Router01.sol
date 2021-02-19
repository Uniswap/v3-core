// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.6;

import { IUniswapV3SwapCallback } from '../../interfaces/callback/IUniswapV3SwapCallback.sol';
import { IUniswapV3MintCallback } from '../../interfaces/callback/IUniswapV3MintCallback.sol';

interface RouterBase {
    /// Gets the spot price for a given amount, by checking the pair's liquidit and current sqrt price
    function quote(uint amountA, uint128 liquidity, uint160 sqrtPriceX96) external pure returns (uint amountB);

    /// Returns the UniswapV3 factory
    function factory() external pure returns (address);

    /// WETH's address
    function WETH() external pure returns (address);

    /// The amount to be received given `amountIn` to the provided `pair`
    function getAmountOut(uint amountIn, address pair) external pure returns (uint amountOut);

    /// The amount to be sent given `amountOut` to the provided `pair`
    function getAmountIn(uint amountOut, address pair) external pure returns (uint amountIn);

    function getAmountsOut(uint amountIn, bytes32[] calldata path) external view returns (uint[] memory amounts);

    function getAmountsIn(uint amountOut, bytes32[] calldata path) external view returns (uint[] memory amounts);
}

interface RouterTokenSwaps is IUniswapV3SwapCallback {
    function swapExactTokensForTokens(
        uint256 amount0In,
        uint160 sqrtPriceLimitX96,
        bytes32[] calldata path, // TODO: Change this to a bytes buffer and just slice it?
        address recipient,
        uint256 deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amount1Out,
        uint160 sqrtPriceLimitX96,
        bytes32[] calldata path,
        address recipient,
        uint256 deadline
    ) external returns (uint[] memory amounts);

    // TODO: Add ETH, Permits, Fee on Transfer
}

interface RouterLP is IUniswapV3MintCallback {
    // If amountADesired is 0 -> single sided with tokenB
    // If amountBDesired is 0 -> single sided with tokenA
    // Check that the liquidity shares received convert to amountAMin and amountBMin
    // after the state transition is done
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 fee,
        int24 tickLower,
        int24 tickUpper,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address recipient,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function removeLiquidity(
        // Params
        address tokenA,
        address tokenB,
        uint256 fee,
        int24 tickLower,
        int24 tickUpper,
        uint liquidity,
        // Recipient
        address recipient,
        // Consistency checks
        uint amountAMin,
        uint amountBMin,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    // TODO: Add ETH, Permits, Fee on Transfer
}

interface IUniswapV3Router is RouterBase, RouterTokenSwaps, RouterLP {}
