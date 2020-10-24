// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '../libraries/PriceMath.sol';

contract PriceMathEchidnaTest {
    using SafeMath for uint256;

    function getInputToRatioAlwaysExceedsNextPrice(
        uint112 reserveIn,
        uint112 reserveOut,
        uint16 lpFee,
        uint224 inOutRatio
    ) external pure {
        require(reserveIn > 1001 && reserveOut > 1001 && lpFee < PriceMath.LP_FEE_BASE);

        uint112 amountIn = PriceMath.getInputToRatio(reserveIn, reserveOut, lpFee, FixedPoint.uq112x112(inOutRatio)) +
            1;
        uint256 amountInLessFee = (uint256(amountIn).mul(PriceMath.LP_FEE_BASE - lpFee)).div(PriceMath.LP_FEE_BASE);

        if (amountInLessFee == 0) {
            assert(amountIn == 0);
            assert((uint256(reserveIn) << 112) / reserveOut >= inOutRatio);
            return;
        }

        uint256 amountOut = ((uint256(reserveOut) * amountIn * (PriceMath.LP_FEE_BASE - lpFee)) /
            (uint256(amountIn) * (PriceMath.LP_FEE_BASE - lpFee) + uint256(reserveIn) * PriceMath.LP_FEE_BASE));

        assert(amountOut > 0 && amountOut < reserveOut);

        uint256 reserveOutAfter = uint256(reserveOut).sub(amountOut);

        assert(((uint256(reserveIn).add(amountIn)) << 112) / reserveOutAfter >= inOutRatio);
    }
}
