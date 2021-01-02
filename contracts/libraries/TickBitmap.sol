// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './BitMath.sol';

// a library for dealing with a bitmap of all ticks initialized states, represented as mapping(int16 => uint256)
// the mapping uses int16 for keys since ticks are represented as int24 and there are 256 (2^8) bits per word
library TickBitmap {
    // computes the position in the mapping where the initialized bit for a tick lives
    // wordPos is the position in the mapping containing the word in which the bit is set
    // bitPos is the position in the word from most to least significant where the flag is set
    function position(int24 tick) private pure returns (int16 wordPos, uint8 bitPos) {
        wordPos = int16(tick >> 8);
        bitPos = uint8(255) - uint8(tick % 256);
    }

    // flips the tick from uninitialized to initialized, or vice versa
    function flipTick(mapping(int16 => uint256) storage self, int24 tick) internal {
        (int16 wordPos, uint8 bitPos) = position(tick);
        uint256 mask = 1 << bitPos;
        self[wordPos] ^= mask;
    }

    // returns the next initialized tick contained in the same word as the current tick that is either lte this tick
    // or greater than this tick
    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        if (lte) {
            (int16 wordPos, uint8 bitPos) = position(tick);
            uint256 word = self[wordPos];
            // all the 1s at or to the left of the current bitPos
            uint256 mask = uint256(-1) - ((1 << bitPos) - 1);
            uint256 masked = word & mask;

            // there are no initialized ticks to the left or at of the current tick, return the leftmost in the word
            if (masked == 0) return (tick - int24(255 - bitPos), false);

            return (tick + (int24(bitPos) - int24(BitMath.leastSignificantBit(masked))), true);
        } else {
            // start from the word of the next tick, since the current tick state doesn't matter
            (int16 wordPos, uint8 bitPos) = position(tick + 1);
            uint256 word = self[wordPos];
            // all the 1s at or to the right of the bitPos
            uint256 mask = bitPos == 255 ? uint256(-1) : (1 << (bitPos + 1)) - 1;
            uint256 masked = word & mask;

            // there are no initialized ticks to the right of the current tick, just return the rightmost in the word
            if (masked == 0) return (tick + 1 + int24(bitPos), false);

            return ((tick + 1) + (int24(bitPos) - int24(BitMath.mostSignificantBit(masked))), true);
        }
    }
}
