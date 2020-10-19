// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

// contains methods for safely casting between integer types
library SafeCast {
    function toUint112(uint256 y) internal pure returns (uint112 z) {
        require((z = uint112(y)) == y, 'SafeCast::toUint112: downcast overflow');
    }

    function toInt112(uint256 y) internal pure returns (int112 z) {
        require((z = int112(y)) >= 0 && uint256(z) == y, 'SafeCast::toInt112: downcast overflow');
    }

    function toInt112(int256 y) internal pure returns (int112 z) {
        require((z = int112(y)) == y, 'SafeCast::toInt112: downcast overflow');
    }
}
