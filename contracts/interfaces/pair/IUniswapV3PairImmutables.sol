// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title Pair state that never changes
/// @notice These parameters are fixed for a pair forever, i.e. the methods will always return the same values
interface IUniswapV3PairImmutables {
    /// @notice The contract that deployed the pair that must adhere to the IUniswapV3Factory interface
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pair, sorted by address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pair, sorted by address
    function token1() external view returns (address);

    /// @notice The pair's fee in pips, i.e. 1e-6
    function fee() external view returns (uint24);

    /// @notice Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e. ..., -6, -3, 0, 3, 6, ...
    /// @dev This value is an int24 to avoid casting even though it is always positive
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pair
    function maxLiquidityPerTick() external view returns (uint128);
}
