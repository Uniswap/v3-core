// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title An interface for a contract that is capable of deploying Uniswap V3 Pairs
/// @notice A contract that constructs a pair must implement this to pass arguments to the pair
/// @dev This is used to remove all constructor arguments from the pair enabling pair addresses to be computed cheaply
/// without storing the entire init code of the pair.
interface IUniswapV3PairDeployer {
    /// @notice Get the parameters to be used in constructing the pair. This is set only transiently during
    /// pair creation.
    /// @dev Called by the pair constructor to fetch the parameters of the pair
    function parameters()
        external
        view
        returns (
            address factory,
            address token0,
            address token1,
            uint24 fee,
            int24 tickSpacing
        );
}
