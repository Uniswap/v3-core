// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

// contains methods for safely casting between integer types
library SafeCast {
    function toUint160(uint256 y) internal pure returns (uint160 z) {
        require((z = uint160(y)) == y, 'DO');
    }

    function toInt128(int256 y) internal pure returns (int128 z) {
        require((z = int128(y)) == y, 'DO');
    }

    function toInt256(uint256 y) internal pure returns (int256 z) {
        require(y < 2**255, 'DO');
        z = int256(y);
    }
}
