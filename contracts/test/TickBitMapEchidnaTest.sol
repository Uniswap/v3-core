// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '../libraries/TickBitMap.sol';

contract TickBitMapEchidnaTest {
    using TickBitMap for mapping(uint256 => uint256);

    mapping(uint256 => uint256) public bitmap;

    function flipTick(int32 tick) public {
        bitmap.flipTick(tick);
    }

    function checkNextInitializedTickWithinOneWordInvariants(int32 tick, bool lte) public view {
        (int32 next, bool initialized) = bitmap.nextInitializedTickWithinOneWord(tick, lte);
        if (lte) {
            assert(next <= tick);
            assert(tick - next < 256);
            // all the ticks between the input tick and the next tick should be uninitialized
            for (int32 i = tick - 1; i > next; i--) {
                assert(!bitmap.isInitialized(i));
            }
            assert(bitmap.isInitialized(next) == initialized);
        } else {
            assert(next > tick);
            assert(next - tick <= 256);
            // all the ticks between the input tick and the next tick should be uninitialized
            for (int32 i = tick + 1; i < next; i++) {
                assert(!bitmap.isInitialized(i));
            }
            assert(bitmap.isInitialized(next) == initialized);
        }
    }

    function checkNextInitializedTickInvariants(int32 tick, bool lte) public view {
        int32 next = bitmap.nextInitializedTick(tick, lte);
        if (lte) {
            assert(next <= tick);
            // all the ticks between the input tick and the next tick should be uninitialized
            for (int32 i = tick - 1; i > next; i--) {
                assert(!bitmap.isInitialized(i));
            }
            assert(bitmap.isInitialized(next));
        } else {
            assert(next > tick);
            // all the ticks between the input tick and the next tick should be uninitialized
            for (int32 i = tick + 1; i < next; i++) {
                assert(!bitmap.isInitialized(i));
            }
            assert(bitmap.isInitialized(next));
        }
    }
}
