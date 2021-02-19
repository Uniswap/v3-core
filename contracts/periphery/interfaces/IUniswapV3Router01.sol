// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.6;

import {IUniswapV3SwapCallback} from '../../interfaces/callback/IUniswapV3SwapCallback.sol';
import {IUniswapV3MintCallback} from '../../interfaces/callback/IUniswapV3MintCallback.sol';

interface RouterBase {
    /// Gets the spot price for a given amount, by checking the pair's liquidit and current sqrt price
    function quote(
        uint256 amountA,
        uint128 liquidity,
        uint160 sqrtPriceX96
    ) external pure returns (uint256 amountB);

    /// Returns the UniswapV3 factory
    function factory() external pure returns (address);

    /// WETH's address
    function WETH() external pure returns (address);

    /// The amount to be received given `amountIn` to the provided `pair`
    function getAmountOut(uint256 amountIn, address pair) external pure returns (uint256 amountOut);

    /// The amount to be sent given `amountOut` to the provided `pair`
    function getAmountIn(uint256 amountOut, address pair) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, bytes32[] calldata path) external view returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, bytes32[] calldata path) external view returns (uint256[] memory amounts);
}

interface RouterTokenSwaps is IUniswapV3SwapCallback {
    function swapExactTokensForTokens(
        uint256 amount0In,
        uint160 sqrtPriceLimitX96,
        bytes32[] calldata path, // TODO: Change this to a bytes buffer and just slice it?
        address recipient,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amount1Out,
        uint160 sqrtPriceLimitX96,
        bytes32[] calldata path,
        address recipient,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

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
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address recipient,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function removeLiquidity(
        // Params
        address tokenA,
        address tokenB,
        uint256 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        // Recipient
        address recipient,
        // Consistency checks
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    // TODO: Add ETH, Permits, Fee on Transfer
}

interface IUniswapV3Router is RouterBase, RouterTokenSwaps, RouterLP {}
