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
        require(reserveIn > 101 && reserveOut > 101 && lpFee < PriceMath.LP_FEE_BASE);

        reserveIn = reserveIn_;
        reserveOut = reserveOut_;
        lpFee = lpFee_;
        inOutRatio = inOutRatio_;

        amountIn = PriceMath.getInputToRatio(reserveIn_, reserveOut_, lpFee_, FixedPoint.uq112x112(inOutRatio_));
    }

    function echidna_ratioAfterAmountInAlwaysExceedsPrice() external view returns (bool) {
        if (reserveIn == 0 || reserveOut == 0 || inOutRatio == 0) {
            return true;
        }
        uint256 amountInLessFee = (uint256(amountIn) * (PriceMath.LP_FEE_BASE - lpFee)) / PriceMath.LP_FEE_BASE;
        uint256 amountOut = reserveOut - ((uint256(reserveIn) * reserveOut) / (uint256(reserveIn) + amountInLessFee));
        return ((uint256(reserveIn) + amountIn) << 112) / (uint256(reserveOut) - amountOut) >= inOutRatio;
    }
}
