// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title Permissionless pair actions
/// @notice Contains pair methods that can be called by anyone
interface IUniswapV3PairActions {
    /// @notice Sets the initial price for the pair
    /// @dev Price is represented as a sqrt(token1/token0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pair as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice Adds liquidity for the given recipient/tickLower/tickUpper position
    /// @dev The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback
    /// in which they must pay any token0 or token1 owed for the liquidity. The amount of token0/token1 due depends
    /// on tickLower, tickUpper, the amount of liquidity and the current price.
    /// @param recipient The address for which the liquidity will be created
    /// @param tickLower The lower tick of the position for which to add liquidity
    /// @param tickUpper The upper tick of the position for which to add liquidity
    /// @param amount The amount of liquidity to mint
    /// @param data Any data that should be passed through to the callback
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external;

    /// @notice Collect fees owed to a position
    /// @dev Does not recompute fees, which must be done either via mint, burn or poke. Must be called by the position
    /// owner. Amounts requested can be 0 to not withdraw fees for that token, or greater than the fees owed to
    /// withdraw all fees owed
    /// @param recipient The address which should receive the fees collected
    /// @param tickLower The lower tick of the position for which to collect fees
    /// @param tickUpper The upper tick of the position for which to collect fees
    /// @param amount0Requested How much token0 should be withdrawn from the fees owed
    /// @param amount1Requested How much token1 should be withdrawn from the fees owed
    /// @return amount0 The amount of fees in token0 collected
    /// @return amount1 The amount of fees in token1 collected
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /// @notice Burn liquidity from the sender and send any tokens owed for the liquidity to a recipient
    /// @dev Can be used to trigger a recalculation of fees owed to a position by calling with an amount of 0
    /// @dev Fees must be collected separately via a call to #collect
    /// @param recipient The address which should receive the tokens
    /// @param tickLower The lower tick of the position for which to burn liquidity
    /// @param tickUpper The upper tick of the position for which to burn liquidity
    /// @param amount How much liquidity to burn
    /// @return amount0 The amount of token0 sent to the recipient
    /// @return amount1 The amount of token1 sent to the recipient
    function burn(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swap token0 for token1, or token1 for token0
    /// @dev The caller of this method receives a callback in the form of IUniswapV3SwapCallback#uniswapV3SwapCallback
    /// @param recipient The address which should receive the output of the swap, either token1 or token0
    /// @param zeroForOne True for swaps token0 to token1, false for token1 to token0
    /// @param amountSpecified Either the exact input (positive) or exact output (negative) amount
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// @param data Any data to pass through to the callback
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external;

    /// @notice Receive token0 and/or token1 and pay it back plus a fee in the callback
    /// @dev The caller of this method receives a callback in the form of IUniswapV3FlashCallback#uniswapV3FlashCallback
    /// @dev Can be used to donate underlying tokens pro-rata to currently in-range liquidity providers by calling
    /// with 0 amount{0,1} and sending the donation amount(s) from the callback
    /// @param recipient The address which should receive the token0 and token1 amounts
    /// @param amount0 The amount of token0 to send
    /// @param amount1 The amount of token1 to send
    /// @param data Any data to pass through to the callback
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /// @notice Increase the maximum number of price and liquidity observations that this pair will store
    /// @dev This method is no-op if the pair already has an observationCardinalityNext greater than or equal to
    /// the input observationCardinalityNext
    /// @param observationCardinalityNext The desired minimum number of observations for the pair to store
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}
