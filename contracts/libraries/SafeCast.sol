// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

// contains methods for safely casting between integer types
library SafeCast {
    function toUint128(uint256 y) internal pure returns (uint128 z) {
        require((z = uint128(y)) == y, 'SafeCast::toUint128: downcast overflow');
    }

    function toUint160(uint256 y) internal pure returns (uint160 z) {
        require((z = uint160(y)) == y, 'SafeCast::toUint160: downcast overflow');
    }

    function toInt128(int256 y) internal pure returns (int128 z) {
        require((z = int128(y)) == y, 'SafeCast::toInt128: downcast overflow');
    }

    function toInt256(uint256 y) internal pure returns (int256 z) {
        require(y < 2**255, 'SafeCast::toInt256: downcast overflow');
        z = int256(y);
    }
}
