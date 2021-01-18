// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './SafeMath.sol';

// contains functions for applying signed liquidity delta values to unsigned liquidity values
library LiquidityMath {
    function toUint128(uint256 y) private pure returns (uint128 z) {
        require((z = uint128(y)) == y, 'DO');
    }

    function addDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        z = toUint128(y < 0 ? SafeMath.sub(x, uint256(-y)) : SafeMath.add(x, uint256(y)));
    }

    function subDelta(uint128 x, int128 y) internal pure returns (uint128 z) {
        z = toUint128(y < 0 ? SafeMath.add(x, uint256(-y)) : SafeMath.sub(x, uint256(y)));
    }
}
