// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/BitMath.sol';

import '../libraries/TickMath.sol';

// a library for dealing with a bitmap of all ticks initialized states, represented as an array of uint256[58]
// the tick's initialization bit position in this map is computed by:
// word: (tick - TickMath.MIN_TICK) / 256
// bit in word: (tick - TickMath.MIN_TICK) % 256
// mask: uint256(1) << (tick - TickMath.MIN_TICK) % 256
// since we have 14703 ticks, we need 58 words to store all the ticks
library TickBitMap {
    // computes the position in the uint256 array where the initialized state for a tick lives
    // bitPos is the 0 indexed position in the word from most to least significant where the flag is set
    function position(int16 tick) private pure returns (uint256 wordPos, uint256 bitPos) {
        require(tick >= TickMath.MIN_TICK, 'TickBitMap::position: tick must be greater than or equal to MIN_TICK');
        require(tick <= TickMath.MAX_TICK, 'TickBitMap::position: tick must be less than or equal to MAX_TICK');
        // this subtraction is safe because tick - TickMath.MIN_TICK is at most 7351 * 2 which fits within int16
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
    function nextInitializedTickWithinOneWord(
        uint256[58] storage self,
        int16 tick,
        bool lte
    ) internal view returns (int16 next, bool initialized) {
        if (lte) {
            (uint256 wordPos, uint256 bitPos) = position(tick);
            uint256 word = self[wordPos];
            // all the 1s at or to the left of the current bitPos
            uint256 mask = uint256(-1) - ((uint256(1) << bitPos) - 1);
            uint256 masked = word & mask;

            // there are no initialized ticks to the left or at of the current tick, return the leftmost in the word
            if (masked == 0) return (tick - int16(255 - bitPos), false);

            return (tick + (int16(bitPos) - int16(BitMath.leastSignificantBit(masked))), true);
        } else {
            // start from the word of the next tick, since the current tick state doesn't matter
            (uint256 wordPos, uint256 bitPos) = position(tick + 1);
            uint256 word = self[wordPos];
            // all the 1s at or to the right of the bitPos
            uint256 mask = bitPos == 255 ? uint256(-1) : (uint256(1) << (bitPos + 1)) - 1;
            uint256 masked = word & mask;

            // there are no initialized ticks to the right of the current tick, just return the rightmost in the word
            if (masked == 0) return (tick + 1 + int16(bitPos), false);

            return ((tick + 1) + (int16(bitPos) - int16(BitMath.mostSignificantBit(masked))), true);
        }
    }

    // same as above, but iterates until it finds the next initialized tick
    function nextInitializedTick(
        uint256[58] storage self,
        int16 tick,
        bool lte
    ) internal view returns (int16 next) {
        bool initialized;
        next = tick;
        if (lte) {
            while (next > TickMath.MIN_TICK && !initialized) {
                (next, initialized) = nextInitializedTickWithinOneWord(self, next, true);
                if (!initialized) next--;
            }
        } else {
            while (next < TickMath.MAX_TICK && !initialized) {
                (next, initialized) = nextInitializedTickWithinOneWord(self, next, false);
            }
        }
        require(initialized, 'TickMath::nextInitializedTick: no initialized next tick');
    }
}
