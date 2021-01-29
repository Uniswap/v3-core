// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

library FeeMath {
    function addCapped(uint128 x, uint256 y) internal pure returns (uint128 z) {
        z = uint128(x + y);
        if (z < x) {
            z = type(uint128).max;
        }
    }
}
