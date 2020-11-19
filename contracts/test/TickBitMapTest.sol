// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '../libraries/TickBitMap.sol';

// a library for dealing with a bitmap of all ticks
contract TickBitMapTest {
    using TickBitMap for uint256[58];

    uint256[58] public bitmap;

    function isInitialized(int16 tick) external view returns (bool) {
        return bitmap.isInitialized(tick);
    }

    function flipTick(int16 tick) external {
        bitmap.flipTick(tick);
    }

    function nextInitializedTick(int16 tick, bool lte) external view returns (int16) {
        return bitmap.nextInitializedTick(tick, lte);
    }
}
