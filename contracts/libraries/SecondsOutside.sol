// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

// enables packing
library SecondsOutside {
    function position(int24 tick, int24 tickSpacing) private pure returns (int24 wordPos, uint8 shift) {
        require(tick % tickSpacing == 0, 'TS');

        int24 compressed = tick / tickSpacing;

        wordPos = compressed >> 3;
        shift = uint8(compressed % 8) * 32;
    }

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

    function clear(
        mapping(int24 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        (int24 wordPos, uint8 shift) = position(tick, tickSpacing);
        self[wordPos] &= ~(uint256(type(uint32).max) << shift);
    }

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

    // returns seconds outside for the given tick
    function get(
        mapping(int24 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal view returns (uint32) {
        (int24 wordPos, uint8 shift) = position(tick, tickSpacing);
        uint256 prev = self[wordPos];
        return uint32(prev >> shift);
    }

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
