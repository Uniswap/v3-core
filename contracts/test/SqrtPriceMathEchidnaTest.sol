// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/FullMath.sol';

import '../libraries/FixedPoint96.sol';
import '../libraries/SqrtPriceMath.sol';

contract SqrtPriceMathEchidnaTest {
    // uniqueness and increasing order
    function mulDivRoundingUpInvariants(
        uint256 x,
        uint256 y,
        uint256 z
    ) external pure {
        require(z > 0);
        uint256 notRoundedUp = FullMath.mulDiv(x, y, z);
        uint256 roundedUp = SqrtPriceMath.mulDivRoundingUp(x, y, z);
        assert(roundedUp >= notRoundedUp);
        assert(roundedUp - notRoundedUp < 2);
        if (roundedUp - notRoundedUp == 1) {
            assert(mulmod(x, y, z) > 0);
        } else {
            assert(mulmod(x, y, z) == 0);
        }
    }

    function getNextPriceInvariants(
        uint160 sqrtP,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) external pure {
        FixedPoint96.uq64x96 memory sqrtQ = SqrtPriceMath.getNextPrice(
            FixedPoint96.uq64x96(sqrtP),
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
