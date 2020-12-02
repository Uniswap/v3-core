// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import './TickBitmap.sol';

// same as TickBitmap, but takes an additional tick spacing argument
// the tickSpacing argument is how tightly packed initialized ticks can be
library SpacedTickBitmap {
    using TickBitmap for mapping(int16 => uint256);

    function compressedTick(int24 tick, int24 tickSpacing) private pure returns (int24) {
        require(tick % tickSpacing == 0, 'SpacedTickBitmap::compressedTick: tick must be a multiple of tickSpacing');
        return tick / tickSpacing;
    }

    function isInitialized(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal view returns (bool) {
        return self.isInitialized(compressedTick(tick, tickSpacing));
    }

    function flipTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        self.flipTick(compressedTick(tick, tickSpacing));
    }

    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        bool lte,
        int24 tickSpacing
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = compressedTick(tick, tickSpacing);
        (next, initialized) = self.nextInitializedTickWithinOneWord(compressed, lte);
        next = tick + (next - compressed) * tickSpacing;
    }

    function nextInitializedTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        bool lte,
        int24 minOrMax,
        int24 tickSpacing
    ) internal view returns (int24 next) {
        int24 compressed = compressedTick(tick, tickSpacing);
        next = self.nextInitializedTick(compressed, lte, compressedTick(minOrMax, tickSpacing));
        next = tick + (next - compressed) * tickSpacing;
    }
}
