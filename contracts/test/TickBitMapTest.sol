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

    function getGasCostOfIsInitialized(int16 tick) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        bitmap.isInitialized(tick);
        return gasBefore - gasleft();
    }

    function flipTick(int16 tick) external {
        bitmap.flipTick(tick);
    }

    function getGasCostOfFlipTick(int16 tick) external returns (uint256) {
        uint256 gasBefore = gasleft();
        bitmap.flipTick(tick);
        return gasBefore - gasleft();
    }

    function nextInitializedTickInSameWord(int16 tick, bool lte) external view returns (int16 next, bool initialized) {
        return bitmap.nextInitializedTickInSameWord(tick, lte);
    }

    function getGasCostOfNextInitializedTickInSameWord(int16 tick, bool lte) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        bitmap.nextInitializedTickInSameWord(tick, lte);
        return gasBefore - gasleft();
    }
}
