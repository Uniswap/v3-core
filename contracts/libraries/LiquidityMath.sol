// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './SafeMath.sol';
import './SafeCast.sol';

// contains functions for applying liquidity delta values which are signed integers, to liquidity values, which are signed
library LiquidityMath {
    function toUint128(uint256 y) private pure returns (uint128 z) {
        require((z = uint128(y)) == y, 'DO');
    }

    function addi(uint128 x, int128 y) internal pure returns (uint128 z) {
        z = toUint128(y < 0 ? SafeMath.sub(x, uint256(-y)) : SafeMath.add(x, uint256(y)));
    }

    function subi(uint128 x, int128 y) internal pure returns (uint128 z) {
        z = toUint128(y < 0 ? SafeMath.add(x, uint256(-y)) : SafeMath.sub(x, uint256(y)));
    }
}
