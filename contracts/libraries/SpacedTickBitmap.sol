// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './TickBitmap.sol';

// same as TickBitmap, but takes an additional tick spacing argument
// the tickSpacing argument is how tightly packed initialized ticks can be
library SpacedTickBitmap {
    using TickBitmap for mapping(int16 => uint256);

    struct Spaced {
        int24 _x;
    }

    struct Compressed {
        int24 _x;
    }

    function compress(int24 tick, int24 tickSpacing) private pure returns (Compressed memory compressed) {
        compressed._x = tick / tickSpacing;
        if (tick < 0 && tick % tickSpacing != 0) compressed._x--; // round towards negative infinity
    }

    function decompress(Compressed memory compressed, int24 tickSpacing) private pure returns (Spaced memory spaced) {
        spaced._x = compressed._x * tickSpacing;
    }

    function flipTick(mapping(int16 =>  uint256) storage self, int24 tick, int24 tickSpacing) internal {
        require(tick % tickSpacing == 0, 'TS'); // ensure that the tick is spaced
        self.flipTick(tick / tickSpacing);
    }

    function nextInitializedTickWithinOneWord(
        mapping(int16 => uint256) storage self,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24, bool) {
        Compressed memory compressed = compress(tick, tickSpacing);
        (int24 compressedNext, bool initialized) = self.nextInitializedTickWithinOneWord(compressed._x, lte);
        return (decompress(Compressed(compressedNext), tickSpacing)._x, initialized);
    }
}
