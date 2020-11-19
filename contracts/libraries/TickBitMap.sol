// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/BitMath.sol';

import '../libraries/TickMath.sol';

// a library for dealing with a bitmap of all ticks initialized states
library TickBitMap {
    // computes the position in the uint256 array where the initialized state for a tick lives
    // bitPos is the 0 indexed position in the word from most to least significant where the flag is set
    function position(int16 tick) private pure returns (uint256 wordPos, uint256 bitPos) {
        require(tick >= TickMath.MIN_TICK, 'TickBitMap::position: tick must be greater than or equal to MIN_TICK');
        require(tick <= TickMath.MAX_TICK, 'TickBitMap::position: tick must be less than or equal to MAX_TICK');
        uint256 bitIndex = uint256(tick - TickMath.MIN_TICK);
        wordPos = bitIndex / 256;
        bitPos = 255 - (bitIndex % 256);
    }

    // returns whether the given tick is initialized
    function isInitialized(uint256[58] storage self, int16 tick) internal view returns (bool) {
        (uint256 wordPos, uint256 bitPos) = position(tick);
        uint256 mask = uint256(1) << bitPos;
        return self[wordPos] & mask != 0;
    }

    // flips the tick from uninitialized to initialized, or vice versa
    function flipTick(uint256[58] storage self, int16 tick) internal {
        (uint256 wordPos, uint256 bitPos) = position(tick);
        uint256 mask = uint256(1) << bitPos;
        self[wordPos] ^= mask;
    }

    // returns the next initialized tick contained in the same word as the current tick that is either lte this tick
    // or greater than this tick
    function nextInitializedTickInSameWord(
        uint256[58] storage self,
        int16 tick,
        bool lte
    ) internal view returns (int16 next, bool initialized) {
        (uint256 wordPos, uint256 bitPos) = position(tick);
        uint256 word = self[wordPos];

        if (lte) {
            // all the 1s to the left of (or equal to) the current bitPos
            uint256 mask = uint256(-1) - ((uint256(1) << bitPos) - 1);
            uint256 masked = word & mask;

            // there are no initialized ticks to the left or at of the current tick, return the leftmost in the word
            if (masked == 0) return (tick - int16(255 - bitPos), false);

            return (tick + int16(bitPos) - int16(BitMath.leastSignificantBit(masked)), true);
        } else {
            // if bitPos is 0, there is no tick to the right in the same word
            if (bitPos == 0) {
                return (tick, word & 1 != 0);
            }

            // all the 1s at or to the right of the bitPos
            uint256 mask = (uint256(1) << bitPos) - 1;
            uint256 masked = word & mask;

            // there are no initialized ticks to the right of the current tick, just return the rightmost in the word
            if (masked == 0) return (tick + int16(bitPos), false);

            return (tick + int16(bitPos) - int16(BitMath.mostSignificantBit(masked)), true);
        }
    }
}
