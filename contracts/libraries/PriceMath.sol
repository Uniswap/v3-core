// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import './UniswapMath.sol';

library PriceMath {
    using FixedPoint for FixedPoint.uq112x112;

    uint24 public constant LP_FEE_BASE = 1000000; // 1000000 pips, or 10000 bips, or 100%

    // TODO temporary
    function getInputToRatio(
        uint112 reserveIn,
        uint112 reserveOut,
        uint24 lpFee,
        FixedPoint.uq112x112 memory inOutRatio
    )
        internal
        pure
        returns (uint112 amountIn)
    {
        FixedPoint.uq112x112 memory reserveRatio = FixedPoint.fraction(reserveIn, reserveOut);
        if (reserveRatio._x >= inOutRatio._x) return 0; // short-circuit if the ratios are equal

        uint inputToRatio = UniswapMath.getInputToRatio(reserveIn, reserveOut, lpFee, inOutRatio._x);
        require(inputToRatio >> 112 <= type(uint112).max, 'PriceMath: TODO');
        return uint112(inputToRatio >> 112);
    }
}
