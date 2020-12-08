// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/FullMath.sol';

import '../libraries/FixedPoint64.sol';
import '../libraries/SqrtPriceMath.sol';

contract SqrtPriceMathEchidnaTest {
    // uniqueness and increasing order
    function mulDivRoundingUpInvariants(
        uint256 x,
        uint256 y,
        uint256 z
    ) external pure {
        uint256 notRoundedUp = FullMath.mulDiv(x, y, z);
        uint256 roundedUp = SqrtPriceMath.mulDivRoundingUp(x, y, z);
        assert(roundedUp >= notRoundedUp);
        assert(roundedUp - notRoundedUp < 2);
    }

    function getNextPriceInvariants(
        uint128 sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external pure {
        FixedPoint64.uq64x64 memory sqrtQ = SqrtPriceMath.getNextPrice(
            FixedPoint64.uq64x64(sqrtP),
            liquidity,
            amountIn,
            zeroForOne
        );

        if (zeroForOne) {
            assert(sqrtQ._x <= sqrtP);
        } else {
            assert(sqrtQ._x >= sqrtP);
        }
    }
}
