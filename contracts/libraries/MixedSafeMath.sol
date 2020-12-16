// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

library MixedSafeMath {
    function addi(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = y < 0 ? x - uint256(-y) : x + uint256(y);
    }

    function subi(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = y < 0 ? x + uint256(-y) : x - uint256(y);
    }
}
