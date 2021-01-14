// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.0;

import '../libraries/TickBitmap.sol';

contract TickBitmapTest {
    using TickBitmap for mapping(int16 => uint256);

    mapping(int16 => uint256) public bitmap;

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

    // returns whether the given tick is initialized
    function isInitialized(int24 tick) external view returns (bool) {
        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(tick, true);
        return next == tick ? initialized : false;
    }
}
