// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './SafeMath.sol';

library MixedSafeMath {
    function addi(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = y < 0 ? SafeMath.sub(x, uint256(-y), 'MAU') : SafeMath.add(x, uint256(y));
    }

    function subi(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = y < 0 ? SafeMath.add(x, uint256(-y)) : SafeMath.sub(x, uint256(y), 'MSU');
    }
}
