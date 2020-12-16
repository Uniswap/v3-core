// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../libraries/TickBitmap.sol';

contract TickBitmapTest {
    using TickBitmap for mapping(int16 => uint256);

    mapping(int16 => uint256) public bitmap;

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
}
