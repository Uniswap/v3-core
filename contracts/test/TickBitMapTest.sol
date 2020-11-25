// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '../libraries/TickBitMap.sol';

// a library for dealing with a bitmap of all ticks
contract TickBitMapTest {
    using TickBitMap for uint256[58];

    uint256[58] public bitmap;

    function isInitialized(int32 tick) external view returns (bool) {
        return bitmap.isInitialized(tick);
    }

    function getGasCostOfIsInitialized(int32 tick) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        bitmap.isInitialized(tick);
        return gasBefore - gasleft();
    }

    function flipTick(int32 tick) external {
        bitmap.flipTick(tick);
    }

    function getGasCostOfFlipTick(int32 tick) external returns (uint256) {
        uint256 gasBefore = gasleft();
        bitmap.flipTick(tick);
        return gasBefore - gasleft();
    }

    function nextInitializedTickWithinOneWord(int32 tick, bool lte)
        external
        view
        returns (int32 next, bool initialized)
    {
        return bitmap.nextInitializedTickWithinOneWord(tick, lte);
    }

    function getGasCostOfNextInitializedTickWithinOneWord(int32 tick, bool lte) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        bitmap.nextInitializedTickWithinOneWord(tick, lte);
        return gasBefore - gasleft();
    }

    function nextInitializedTick(int32 tick, bool lte) external view returns (int32 next) {
        return bitmap.nextInitializedTick(tick, lte);
    }

    function getGasCostOfNextInitializedTick(int32 tick, bool lte) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        bitmap.nextInitializedTick(tick, lte);
        return gasBefore - gasleft();
    }
}
