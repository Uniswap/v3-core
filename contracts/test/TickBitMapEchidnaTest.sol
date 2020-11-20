// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '../libraries/TickBitMap.sol';

contract TickBitMapEchidnaTest {
    using TickBitMap for uint256[58];

    uint256[58] public bitmap;

    function flipTick(int16 tick) public {
        bitmap.flipTick(tick);
    }

    function checkNextInitializedTickInvariants(int16 tick, bool lte) public view {
        int16 next = bitmap.nextInitializedTick(tick, lte);
        if (lte) {
            assert(next <= tick);
            // all the ticks between the input tick and the next tick should be uninitialized
            for (int16 i = tick - 1; i > next; i--) {
                assert(!bitmap.isInitialized(i));
            }
            assert(bitmap.isInitialized(next));
        } else {
            assert(next > tick);
            // all the ticks between the input tick and the next tick should be uninitialized
            for (int16 i = tick + 1; i < next; i++) {
                assert(!bitmap.isInitialized(i));
            }
            assert(bitmap.isInitialized(next));
        }
    }
}
