// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.12;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import '../libraries/PriceMath.sol';

contract PriceMathEchidnaTest {
    function getInputToRatioAlwaysExceedsNextPrice(
        uint112 reserveIn,
        uint112 reserveOut,
        uint16 lpFee,
        uint224 inOutRatio
    ) external pure {
        require(reserveIn > 1001 && reserveOut > 1001 && lpFee < PriceMath.LP_FEE_BASE);

        uint112 amountIn = PriceMath.getInputToRatio(reserveIn, reserveOut, lpFee, FixedPoint.uq112x112(inOutRatio));

        uint256 amountInLessFee = (uint256(amountIn) * (PriceMath.LP_FEE_BASE - lpFee)) / PriceMath.LP_FEE_BASE;
        uint256 amountOut = reserveOut - ((uint256(reserveIn) * reserveOut) / (uint256(reserveIn) + amountInLessFee));

        assert(((uint256(reserveIn) + amountIn) << 112) / (reserveOut - amountOut) >= inOutRatio);
    }
}
