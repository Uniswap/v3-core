// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Limit orders for UniswapV3Pool
/// @notice Contains methods related to the added Limit Order feature
interface IUniswapV3PoolLimitOrder {
    /// @notice Create a limit order of size at a given `tickLower` 
    /// @notice `tickLower` should not equal to `slot0.tick`
    /// @param recipient Address of the recipient/owner of the limit order
    /// @param tickLower The lower tick of the limit order place on interval [tickLower, tickLower + tickSpacing)
    /// @param amount The amount of tokens to allocate. `token0` if `tickLower` > `slot0.tick` or `token1` if
    ///     `tickLower` < `slot0.tick`.
    function createLimitOrder(address recipient, int24 tickLower, uint128 amount) external;

    /// @notice Collects liquidated limit orders or cancels an existing one, if not yet executed.
    /// @param recipient Address of the recipient of the claimed limit order tokens
    /// @param tickLower The lower tick where the order was placed
    function collectLimitOrder(address recipient, int24 tickLower) external;
}