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
    function tickSpacing() external view returns (int24);

    /// @notice The smallest tick, i.e. smallest price, that is allowed to be used by a position
    function minTick() external view returns (int24);

    /// @notice The largest tick, i.e. largest price, that is allowed to be used by a position
    function maxTick() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    function maxLiquidityPerTick() external view returns (uint128);
}
