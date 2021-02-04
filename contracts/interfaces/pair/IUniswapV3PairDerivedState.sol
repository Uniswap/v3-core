// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title Pair state that is not stored
/// @notice Contains view functions to provide information about the pair that is computed rather than stored on the
///     blockchain and may have variable gas costs
interface IUniswapV3PairDerivedState {
    /// @notice Returns a relative timestamp value representing how long in seconds the pair has spent between
    /// tickLower and tickUpper
    /// @param tickLower The lower tick of the range for which to get the seconds inside
    /// @param tickUpper The upper tick of the range for which to get the seconds inside
    /// @return A relative timestamp for how long the pair spent in the tick range
    /// @dev This timestamp is strictly relative. To get a useful elapsed time (i.e. duration) value, the value returned
    /// by this method should be checkpointed externally after a position is minted and again before a position is
    /// burned. Thus the external contract must control the lifecycle of the position.
    function secondsInside(int24 tickLower, int24 tickUpper) external view returns (uint32);

    /// @notice Returns the cumulative tick and liquidity as of a timestamp secondsAgo from the current block timestamp.
    /// @param secondsAgo How long ago the cumulative tick and liquidity should be returned from
    /// @return tickCumulative Cumulative tick value as of `secondsAgo` from the current block timestamp
    /// @return liquidityCumulative Cumulative liquidity-in-range value as of `secondsAgo` from the current block
    /// timestamp
    /// @dev To get a time weighted average tick or liquidity-in-range, you must call this twice, once with the start
    /// of the period and again with the end of the period. E.g. to get the last hour time-weighted average tick,
    /// you must call it with secondsAgo = 3600, and secondsAgo = 0.
    /// @dev The time weighted average tick represents the geometric time weighted average price of the pair, in
    /// log base sqrt(1.0001) of token1 / token0. The TickMath library allows you to compute sqrt(1.0001)^tick
    /// as a fixed point Q128.128 in a uint256 container.
    function scry(uint32 secondsAgo) external view returns (int56 tickCumulative, uint160 liquidityCumulative);
}
