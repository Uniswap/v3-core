// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/// @title Stores packed 32 bit timestamp values
/// @notice Contains methods for working with a mapping from tick to 32 bit timestamp values, specifically seconds
/// spent outside the tick.
/// @dev The mapping uses int24 for keys since ticks are represented as int24 and there are 8 (2^3) values per word.
library SecondsOutside {
    /// @notice Computes the position of the least significant bit of the 32 bit seconds outside value for a given tick
    /// @param tick the tick for which to compute the position
    /// @param tickSpacing the spacing between usable ticks
    /// @return wordPos the key in the mapping containing the word in which the bit is stored
    /// @return shift the position of the least significant bit in the 32 bit seconds outside
    function position(int24 tick, int24 tickSpacing) private pure returns (int24 wordPos, uint8 shift) {
        require(tick % tickSpacing == 0);

        int24 compressed = tick / tickSpacing;

        wordPos = compressed >> 3;
        shift = uint8(compressed % 8) * 32;
    }

    /// @notice Called the first time a tick is used to set the seconds outside value. Assumes the tick is not
    /// initialized.
    /// @param self the packed mapping of tick to seconds outside
    /// @param tick the tick to be initialized
    /// @param tickCurrent the current tick
    /// @param tickSpacing the spacing between usable ticks
    /// @param time the current timestamp
    function initialize(
        mapping(int24 => uint256) storage self,
        int24 tick,
        int24 tickCurrent,
        int24 tickSpacing,
        uint32 time
    ) internal {
        if (tick <= tickCurrent) {
            (int24 wordPos, uint8 shift) = position(tick, tickSpacing);
            self[wordPos] |= uint256(time) << shift;
        }
    }

    /// @notice Called when a tick is no longer used, to clear the seconds outside value of the tick
    /// @param self the packed mapping of tick to seconds outside
    /// @param tick the tick to be cleared
    /// @param tickSpacing the spacing between usable ticks
    function clear(
        mapping(int24 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        (int24 wordPos, uint8 shift) = position(tick, tickSpacing);
        self[wordPos] &= ~(uint256(type(uint32).max) << shift);
    }

    /// @notice Called when an initialized tick is crossed to update the seconds outside for that tick. Must be called
    /// every time an initialized tick is crossed
    /// @param self the packed mapping of tick to seconds outside
    /// @param tick the tick to be crossed
    /// @param tickSpacing the spacing between usable ticks
    /// @param time the current block timestamp truncated to 32 bits
    function cross(
        mapping(int24 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        uint32 time
    ) internal {
        (int24 wordPos, uint8 shift) = position(tick, tickSpacing);
        uint256 prev = self[wordPos];
        uint32 timePrev = uint32(prev >> shift);
        uint32 timeNext = time - timePrev;
        self[wordPos] = (prev ^ (uint256(timePrev) << shift)) | (uint256(timeNext) << shift);
    }

    /// @notice Get the seconds outside for an initialized tick. Should be called only on initialized ticks.
    /// @param self the packed mapping of tick to seconds outside
    /// @param tick the tick to get the seconds outside value for
    /// @param tickSpacing the spacing between usable ticks
    /// @return the seconds outside value for that tick
    function get(
        mapping(int24 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal view returns (uint32) {
        (int24 wordPos, uint8 shift) = position(tick, tickSpacing);
        uint256 prev = self[wordPos];
        return uint32(prev >> shift);
    }

    /// @notice Get the seconds inside a tick range, assuming both tickLower and tickUpper are initialized
    /// @param self the packed mapping of tick to seconds outside
    /// @param tickLower the lower tick for which to get seconds inside
    /// @param tickUpper the upper tick for which to get seconds inside
    /// @param tickCurrent the current tick
    /// @param tickSpacing the spacing between usable ticks
    /// @return a relative seconds inside value that can be snapshotted and compared to a later snapshot to compute
    /// time spent between tickLower and tickUpper, i.e. time that a position's liquidity was in use.
    function secondsInside(
        mapping(int24 => uint256) storage self,
        int24 tickLower,
        int24 tickUpper,
        int24 tickCurrent,
        int24 tickSpacing,
        uint32 time
    ) internal view returns (uint32) {
        // calculate seconds below
        uint32 secondsBelow;
        if (tickCurrent >= tickLower) {
            secondsBelow = get(self, tickLower, tickSpacing);
        } else {
            secondsBelow = time - get(self, tickLower, tickSpacing);
        }

        // calculate seconds above
        uint32 secondsAbove;
        if (tickCurrent < tickUpper) {
            secondsAbove = get(self, tickUpper, tickSpacing);
        } else {
            secondsAbove = time - get(self, tickUpper, tickSpacing);
        }

        return time - secondsBelow - secondsAbove;
    }
}
