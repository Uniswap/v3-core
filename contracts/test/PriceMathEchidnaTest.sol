// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

import '../libraries/PriceMath.sol';

contract PriceMathEchidnaTest {
    uint112 reserveIn;
    uint112 reserveOut;
    uint16 lpFee;
    uint224 inOutRatio;

    uint112 amountIn;

    function storeInputToRatio(
        uint112 reserveIn_,
        uint112 reserveOut_,
        uint16 lpFee_,
        uint224 inOutRatio_
    ) external {
        reserveIn = reserveIn_;
        reserveOut = reserveOut_;
        lpFee = lpFee_;
        inOutRatio = inOutRatio_;

        amountIn = PriceMath.getInputToRatio(reserveIn_, reserveOut_, lpFee_, FixedPoint.uq112x112(inOutRatio_));
    }

    function echidna_ratioAfterAmountInAlwaysExceedsPrice() external view returns (bool) {
        if (reserveIn == 0 || reserveOut == 0 || lpFee == 0 || inOutRatio == 0) {
            return true;
        }
        uint112 amountOut = (amountIn * (PriceMath.LP_FEE_BASE - lpFee)) / PriceMath.LP_FEE_BASE;
        return ((reserveIn + amountIn) << 112) / (reserveOut - amountOut) >= inOutRatio;
    }
}
