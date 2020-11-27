// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/BitMath.sol';

// a library for dealing with a bitmap of all ticks initialized states, represented as mapping(uint256 => uint256)
// the tick's initialization bit position in this map is computed by:
// word: (tick - type(int24).min) / 256
// bit in word: (tick - type(int24).min) % 256
// mask: uint256(1) << (tick - type(int24).min) % 256
library TickBitMap {
    // computes the position in the uint256 array where the initialized state for a tick lives
    // bitPos is the 0 indexed position in the word from most to least significant where the flag is set
    function position(int24 tick) private pure returns (uint256 wordPos, uint256 bitPos) {
        // moves the tick into positive integer space while making sure all ticks are adjacent
        uint256 bitIndex = uint256(
            int256(tick) + 8388608 /* equivalent to -type(int24).min */
        );
        wordPos = bitIndex / 256;
        bitPos = 255 - (bitIndex % 256);
    }

    // returns whether the given tick is initialized
    function isInitialized(mapping(uint256 => uint256) storage self, int24 tick) internal view returns (bool) {
        (uint256 wordPos, uint256 bitPos) = position(tick);
        uint256 mask = uint256(1) << bitPos;
        return self[wordPos] & mask != 0;
    }

    // flips the tick from uninitialized to initialized, or vice versa
    function flipTick(mapping(uint256 => uint256) storage self, int24 tick) internal {
        (uint256 wordPos, uint256 bitPos) = position(tick);
        uint256 mask = uint256(1) << bitPos;
        self[wordPos] ^= mask;
    }

    // returns the next initialized tick contained in the same word as the current tick that is either lte this tick
    // or greater than this tick
    function nextInitializedTickWithinOneWord(
        mapping(uint256 => uint256) storage self,
        int24 tick,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        if (lte) {
            (uint256 wordPos, uint256 bitPos) = position(tick);
            uint256 word = self[wordPos];
            // all the 1s at or to the left of the current bitPos
            uint256 mask = uint256(-1) - ((uint256(1) << bitPos) - 1);
            uint256 masked = word & mask;

            // there are no initialized ticks to the left or at of the current tick, return the leftmost in the word
            if (masked == 0) return (tick - int24(255 - bitPos), false);

            return (tick + (int24(bitPos) - int24(BitMath.leastSignificantBit(masked))), true);
        } else {
            // start from the word of the next tick, since the current tick state doesn't matter
            (uint256 wordPos, uint256 bitPos) = position(tick + 1);
            uint256 word = self[wordPos];
            // all the 1s at or to the right of the bitPos
            uint256 mask = bitPos == 255 ? uint256(-1) : (uint256(1) << (bitPos + 1)) - 1;
            uint256 masked = word & mask;

            // there are no initialized ticks to the right of the current tick, just return the rightmost in the word
            if (masked == 0) return (tick + 1 + int24(bitPos), false);

            return ((tick + 1) + (int24(bitPos) - int24(BitMath.mostSignificantBit(masked))), true);
        }
    }

    // same as above, but iterates until it finds the next initialized tick
    function nextInitializedTick(
        mapping(uint256 => uint256) storage self,
        int24 tick,
        bool lte,
        int24 minOrMax
    ) internal view returns (int24 next) {
        require(
            lte ? minOrMax <= tick : minOrMax > tick,
            'TickBitMap::nextInitializedTick: minOrMax must be in the direction of lte'
        );

        bool initialized;
        next = tick;
        if (lte) {
            while (next >= minOrMax && !initialized) {
                (next, initialized) = nextInitializedTickWithinOneWord(self, next, true);
                if (!initialized) next--;
            }
        } else {
            while (next < minOrMax && !initialized) {
                (next, initialized) = nextInitializedTickWithinOneWord(self, next, false);
            }
        }
        require(initialized, 'TickMath::nextInitializedTick: no initialized next tick');
    }
}
