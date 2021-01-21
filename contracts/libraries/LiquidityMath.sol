// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title LiquidityMath
/// @notice contains functions for applying signed liquidity delta values to unsigned liquidity values
library LiquidityMath {
    /// @param x
    /// @param y
    /// @return z
    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            require((z = x - uint128(-y)) < x, 'LS');
        } else {
            require((z = x + uint128(y)) >= x, 'LA');
        }
    }

    /// @param x
    /// @param y
    /// @return z
    function subDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            require((z = x + uint128(-y)) > x, 'LA');
        } else {
            require((z = x - uint128(y)) <= x, 'LS');
        }
    }
}
