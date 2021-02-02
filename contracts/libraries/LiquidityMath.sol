// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

/// @title Math library for liquidity
library LiquidityMath {
    /// @notice Add a signed liquidity delta to liquidity and revert if it overflows or underflows
    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            require((z = x - uint128(-y)) < x, 'LS');
        } else {
            require((z = x + uint128(y)) >= x, 'LA');
        }
    }

    /// @notice Subtract a signed liquidity delta to liquidity and revert if it overflows or underflows
    function subDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            require((z = x + uint128(-y)) > x, 'LA');
        } else {
            require((z = x - uint128(y)) <= x, 'LS');
        }
    }
}
