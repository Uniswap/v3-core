// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '../libraries/TickMath.sol';

// a library for dealing with a bitmap of all ticks
library TickBitMap {
    function position(int16 tick) private pure returns (uint256 word, uint256 bit) {
        uint256 bitIndex = uint256(tick - TickMath.MIN_TICK);
        word = bitIndex / 256;
        bit = bitIndex % 256;
    }

    function isInitialized(uint256[58] storage self, int16 tick) internal view returns (bool) {
        (uint256 word, uint256 bit) = position(tick);
        uint256 mask = uint256(1) << bit;
        return self[word] & mask != 0;
    }

    function flipTick(uint256[58] storage self, int16 tick) internal {
        (uint256 word, uint256 bit) = position(tick);
        self[word] ^= uint256(1) << bit;
    }
}
