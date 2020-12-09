// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '../libraries/TickMath.sol';
import '../libraries/TickBitmap.sol';

contract TickBitmapEchidnaTest {
    using TickBitmap for mapping(int16 => uint256);

    mapping(int16 => uint256) private bitmap;

    function flipTick(int24 tick) external {
        bool before = bitmap.isInitialized(tick);
        bitmap.flipTick(tick);
        assert(bitmap.isInitialized(tick) == !before);
    }

    function checkNextInitializedTickWithinOneWordInvariants(int24 tick, bool lte) external view {
        (int24 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(tick, lte);
        if (lte) {
            require(tick >= TickMath.MIN_TICK);
            assert(next <= tick);
            assert(tick - next < 256);
            // all the ticks between the input tick and the next tick should be uninitialized
            for (int24 i = tick - 1; i > next; i--) {
                assert(!bitmap.isInitialized(i));
            }
            assert(bitmap.isInitialized(next) == initialized);
        } else {
            require(tick < TickMath.MAX_TICK);
            assert(next > tick);
            assert(next - tick <= 256);
            // all the ticks between the input tick and the next tick should be uninitialized
            for (int24 i = tick + 1; i < next; i++) {
                assert(!bitmap.isInitialized(i));
            }
            assert(bitmap.isInitialized(next) == initialized);
        }
    }
}
