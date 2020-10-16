// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

library SafeMathExtra {
    // TODO check that this is gas efficient as compared to requiring `y <= type(uint112).max`
    function toUint112(uint256 y) internal pure returns (uint112 z) {
        require((z = uint112(y)) == y, 'downcast-overflow');
    }

    // TODO check that this is gas efficient as compared to requiring `y <= type(int112).max`
    function toInt112(uint256 y) internal pure returns (int112 z) {
        require((z = int112(y)) >= 0 && uint256(z) == y, 'downcast-overflow');
    }

    // TODO check that this is gas efficient as compared to requiring `y <= type(int128).max`
    function itoInt112(int256 y) internal pure returns (int112 z) {
        require((z = int112(y)) == y, 'downcast-overflow');
    }

    function addi(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = y < 0 ? SafeMath.sub(x, uint256(-y)) : SafeMath.add(x, uint256(y));
    }

    function subi(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = y < 0 ? SafeMath.add(x, uint256(-y)) : SafeMath.sub(x, uint256(y));
    }
}
