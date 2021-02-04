// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title Callback for IUniswapV3PairActions#mint
/// @notice Any contract that calls IUniswapV3PairActions#mint must implement this interface
interface IUniswapV3MintCallback {
    /// @notice Called on `msg.sender` after making updates to the position. Allows the sender to pay the tokens
    /// due for the minted liquidity
    /// @param amount0Owed The amount of token0 due to the pair for the minted liquidity
    /// @param amount1Owed The amount of token1 due to the pair for the minted liquidity
    /// @param data Any data passed through by the caller via the IUniswapV3PairActions#mint call
    /// @dev The caller of this method must be checked to be a UniswapV3Pair deployed by the canonical factory
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}
