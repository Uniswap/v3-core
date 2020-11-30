// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '../libraries/TickBitMap.sol';

// a library for dealing with a bitmap of all ticks
contract TickBitMapTest {
    using TickBitMap for mapping(uint256 => uint256);

    mapping(uint256 => uint256) public bitmap;

    function isInitialized(int24 tick) external view returns (bool) {
        return bitmap.isInitialized(tick);
    }

    function getGasCostOfIsInitialized(int24 tick) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        bitmap.isInitialized(tick);
        return gasBefore - gasleft();
    }

    function flipTick(int24 tick) external {
        bitmap.flipTick(tick);
    }

    function getGasCostOfFlipTick(int24 tick) external returns (uint256) {
        uint256 gasBefore = gasleft();
        bitmap.flipTick(tick);
        return gasBefore - gasleft();
    }

    function nextInitializedTickWithinOneWord(int24 tick, bool lte)
        external
        view
        returns (int24 next, bool initialized)
    {
        return bitmap.nextInitializedTickWithinOneWord(tick, lte);
    }

    function getGasCostOfNextInitializedTickWithinOneWord(int24 tick, bool lte) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        bitmap.nextInitializedTickWithinOneWord(tick, lte);
        return gasBefore - gasleft();
    }

    function nextInitializedTick(
        int24 tick,
        bool lte,
        int24 minOrMax
    ) external view returns (int24 next) {
        return bitmap.nextInitializedTick(tick, lte, minOrMax);
    }

    function getGasCostOfNextInitializedTick(
        int24 tick,
        bool lte,
        int24 minOrMax
    ) external view returns (uint256) {
        uint256 gasBefore = gasleft();
        bitmap.nextInitializedTick(tick, lte, minOrMax);
        return gasBefore - gasleft();
    }
}
