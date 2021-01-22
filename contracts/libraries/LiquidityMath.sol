// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

// contains functions for applying signed liquidity delta values to unsigned liquidity values
library LiquidityMath {
    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            require((z = x - uint128(-y)) < x, 'LS');
        } else {
            require((z = x + uint128(y)) >= x, 'LA');
        }
    }

    function subDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        if (y < 0) {
            require((z = x + uint128(-y)) > x, 'LA');
        } else {
            require((z = x - uint128(y)) <= x, 'LS');
        }
    }

    function addCapped(uint128 x, uint256 y) internal pure returns (uint128 z) {
        z = uint128(x + y);
        if (z < x) {
            z = type(uint128).max;
        }
    }
}
