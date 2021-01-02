// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './TickBitmap.sol';

// same as TickBitmap, but takes an additional tick spacing argument
// the tickSpacing argument is how tightly packed initialized ticks can be
library SpacedTickBitmap {
    using TickBitmap for mapping(int16 => uint256);

    function flipTick(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing
    ) internal {
        require(tick % tickSpacing == 0, 'TS'); // ensure that the tick is spaced
        self.flipTick(tick / tickSpacing);
    }

    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24 next, bool initialized) {
        int24 compressed = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed--; // round towards negative infinity
        (next, initialized) = self.nextInitializedTickWithinOneWord(compressed, lte);
        next *= tickSpacing;
    }
}
