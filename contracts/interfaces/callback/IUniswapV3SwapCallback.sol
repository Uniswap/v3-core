// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PairActions#swap
/// @notice A contract that calls IUniswapV3PairActions#swap must implement this interface
interface IUniswapV3SwapCallback {
    /// @notice Called on `msg.sender` after performing a swap and transferring any output tokens to the recipient
    /// @param amount0Delta the amount of token0 that was sent (negative) or must be received (positive) by the pair by
    ///     the end of the swap. If positive, the callback must send that amount of token0 to the pair.
    /// @param amount1Delta the amount of token1 that was sent (negative) or must be received (positive) by the pair by
    ///     the end of the swap. If positive, the callback must send that amount of token1 to the pair.
    /// @param data any data passed through by the caller via the IUniswapV3PairActions#swap call
    /// @dev The caller of this method must be checked to be a UniswapV3Pair deployed by the canonical factory
    /// @dev amount0 and amount1 can both be 0
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}
