// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';

import './SafeCast.sol';

library PriceMath {
    using SafeMath for *;
    using FixedPoint for FixedPoint.uq112x112;
    using SafeCast for *;

    uint16 public constant LP_FEE_BASE = 1e4; // i.e. 10k bips, 100%
    // 2**112 - 1, can be added to the input amount before truncating so that we always round up in getInputToRatio
    uint256 private constant ROUND_UP = 0xffffffffffffffffffffffffffff;

    // amountIn here is assumed to have already been discounted by the fee
    function getAmountOut(
        uint112 reserveIn,
        uint112 reserveOut,
        uint112 amountIn
    ) internal pure returns (uint112) {
        return ((uint256(reserveOut) * amountIn) / (uint256(reserveIn) + amountIn)).toUint112();
    }

    function mulDivRoundingUp(
        uint256 h,
        uint256 l,
        uint256 d
    ) private pure returns (uint256) {
        bool roundUp = mulmod(h, l, d) > 0;
        return FullMath.mulDiv(h, l, d) + (roundUp ? 1 : 0);
    }

    function getInputToRatio(
        uint112 reserve0,
        uint112 reserve1,
        uint16 lpFee,
        FixedPoint.uq112x112 memory priceTarget, // always reserve1/reserve0
        bool zeroForOne
    ) internal pure returns (uint112 amountIn) {
        // short-circuit if we're already at or past the target price
        FixedPoint.uq112x112 memory price = FixedPoint.fraction(reserve1, reserve0);
        if (zeroForOne) {
            if (price._x <= priceTarget._x) return 0;
        } else if (price._x >= priceTarget._x) return 0;

        uint256 k = uint256(reserve0) * reserve1;

        // compute the square of output reserves (rounded up)
        uint256 reserveOutNextSquared;
        if (zeroForOne) {
            reserveOutNextSquared = mulDivRoundingUp(k, priceTarget._x, uint256(1) << 112);
        } else {
            reserveOutNextSquared = mulDivRoundingUp(k, uint256(1) << 112, priceTarget._x);
        }

        // compute exact output reserves (rounded up), because ceil(sqrt(ceil(x))) := ceil(sqrt(x)) ∀ x > 0
        uint256 reserveOutNextMinimum = Babylonian.sqrt(reserveOutNextSquared);
        // this line is because Babylonian.sqrt can be off by up to 2 (remove this line if possible)
        while (reserveOutNextMinimum**2 < reserveOutNextSquared) reserveOutNextMinimum++;

        // compute input reserves (rounded down), s.t. 1 more wei of input leads to the price being exceeded
        uint256 reserveInNext = zeroForOne
            ? (reserveOutNextMinimum << 112) / priceTarget._x
            : FullMath.mulDiv(reserveOutNextMinimum, priceTarget._x, uint256(1) << 112);

        uint112 reserveIn = zeroForOne ? reserve0 : reserve1;
        uint112 amountInLessFee = uint112(reserveInNext - reserveIn);

        // compute the (rounded-up) amountIn scaled by the current fee
        bool roundUp = (uint256(amountIn) * LP_FEE_BASE) % (LP_FEE_BASE - lpFee) > 0;
        amountIn = uint112(((uint256(amountInLessFee) * LP_FEE_BASE) / (LP_FEE_BASE - lpFee)) + (roundUp ? 1 : 0));
        // should be true because floor(ceil(x*LP_FEE_BASE/FEE)*FEE/LP_FEE_BASE) - x := 0 ∀ x ∈ Z
        //        assert((amountIn * lpFee) / LP_FEE_BASE == reserveInNext - reserveIn);

        //        if (zeroForOne) {
        //            // check that input reserve * minimum output reserve satisfying the invariant satisfied price inequality
        //            roundUp = k % reserveInNext > 0;
        //            uint256 reserveOutImplied = k / reserveInNext + (roundUp ? 1 : 0);
        //            assert(FixedPoint.fraction(uint112(reserveOutImplied), uint112(reserveInNext))._x >= priceTarget._x);
        //            roundUp = k % (reserveInNext + 1) > 0;
        //            reserveOutImplied = k / (reserveInNext + 1) + (roundUp ? 1 : 0);
        //            assert(FixedPoint.fraction(uint112(reserveOutImplied), uint112(reserveInNext + 1))._x < priceTarget._x);
        //        } else {
        //            roundUp = k % reserveInNext > 0;
        //            uint256 reserveOutImplied = k / reserveInNext + (roundUp ? 1 : 0);
        //            assert(FixedPoint.fraction(uint112(reserveInNext), uint112(reserveOutImplied))._x <= priceTarget._x);
        //            roundUp = k % (reserveInNext + 1) > 0;
        //            reserveOutImplied = k / (reserveInNext + 1) + (roundUp ? 1 : 0);
        //            assert(FixedPoint.fraction(uint112(reserveInNext + 1), uint112(reserveOutImplied))._x > priceTarget._x);
        //        }
    }
}
