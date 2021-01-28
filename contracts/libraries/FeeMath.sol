// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

library FeeMath {
    function addCapped(uint128 x, uint256 y) internal pure returns (uint128 z) {
        z = uint128(x + y);
        if (z < x) {
            z = type(uint128).max;
        }
    }

    function divRoundingUp(uint256 x, uint256 d) internal pure returns (uint256) {
        // addition is safe because (type(uint256).max / 1) + (type(uint256).max % 1 > 0 ? 1 : 0) == type(uint256).max
        return (x / d) + (x % d > 0 ? 1 : 0);
    }
}
