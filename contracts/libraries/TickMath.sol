// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import 'abdk-libraries-solidity/ABDKMathQuad.sol';
import './UniswapMath.sol';

// calculates prices, encoded as uq112x112 fixed points, corresponding to reserves ratios of 1.01**tick
library TickMath {
    // the minimum price that can be represented by a uq112x112 fixed point (excluding 0) is 1 / (2**112 - 1)
    // therefore, the smallest possible tick that corresponds to a representable price is -7802, because:
    // 1.01**tick >= 1 / (2**112 - 1)
    // tick >= log_1.01(1 / (2**112 - 1))
    // tick = ceil(log_1.01(1 / (2**112 - 1))) = -7802
    int16 public constant MIN_TICK = -7802;
    // the minimum price that can be represented by a uq112x112 fixed point is (2**112 - 1) / 1 = 2**112 - 1
    // therefore, the largest possible tick that corresponds to a representable price is 7802, because:
    // 1.01**tick <= 2**112 - 1
    // tick <= log_1.01(2**112 - 1)
    // tick = floor(log_1.01(2**112 - 1)) = 7802
    int16 public constant MAX_TICK = 7802;

    // TODO temporary
    function getRatioAtTick(int16 tick) internal pure returns (FixedPoint.uq112x112 memory) {
        uint ratioAtTick = UniswapMath.getRatioAtTick(tick) >> 16;
        require(ratioAtTick <= type(uint224).max && ratioAtTick > 0, 'TickMath: TODO');
        return FixedPoint.uq112x112(uint224(ratioAtTick));
    }
}
