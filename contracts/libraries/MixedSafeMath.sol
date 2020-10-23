// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

library MixedSafeMath {
    function addi(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = y < 0 ? SafeMath.sub(x, uint256(-y), 'MixedSafeMath::addi: underflow') : SafeMath.add(x, uint256(y));
    }

    function subi(uint256 x, int256 y) internal pure returns (uint256 z) {
        z = y < 0 ? SafeMath.add(x, uint256(-y)) : SafeMath.sub(x, uint256(y), 'MixedSafeMath::subi: overflow');
    }
}
