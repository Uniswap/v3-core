// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

// contains methods for safely casting between integer types
library SafeCast {
    // TODO check that this is gas efficient as compared to requiring `y <= type(uint112).max`
    function toUint112(uint256 y) internal pure returns (uint112 z) {
        require((z = uint112(y)) == y, 'SafeCast::toUint112: downcast overflow');
    }

    // TODO check that this is gas efficient as compared to requiring `y <= type(int112).max`
    function toInt112(uint256 y) internal pure returns (int112 z) {
        require((z = int112(y)) >= 0 && uint256(z) == y, 'SafeCast::toInt112: downcast overflow');
    }

    // TODO check that this is gas efficient as compared to requiring `y <= type(int128).max`
    function itoInt112(int256 y) internal pure returns (int112 z) {
        require((z = int112(y)) == y, 'SafeCast::itoInt112: downcast overflow');
    }
}
