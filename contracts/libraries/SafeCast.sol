// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

// contains methods for safely casting between integer types
library SafeCast {
    function toUint112(uint256 y) internal pure returns (uint112 z) {
        require((z = uint112(y)) == y, 'SafeCast::toUint112: downcast overflow');
    }

    function toInt96(int256 y) internal pure returns (int96 z) {
        require((z = int96(y)) == y, 'SafeCast::toInt96: downcast overflow');
    }

    function toInt256(uint256 y) internal pure returns (int256 z) {
        require(y < 2**255, 'SafeCast::toInt256: downcast overflow');
        z = int256(y);
    }
}
