// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@openzeppelin/contracts/math/Math.sol';

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';
import '@uniswap/lib/contracts/libraries/BitMath.sol';

import './SafeCast.sol';

library PriceMath {
    using SafeCast for uint256;

    uint16 public constant LP_FEE_BASE = 1e4; // i.e. 10k bips, 100%

    function mulDivRoundingUp(
        uint256 x,
        uint256 y,
        uint256 d
    ) private pure returns (uint256) {
        return FullMath.mulDiv(x, y, d) + (mulmod(x, y, d) > 0 ? 1 : 0);
    }

    // amountIn here is assumed to have already been discounted by the fee
    function getAmountOut(
        uint112 reserveIn,
        uint112 reserveOut,
        uint112 amountIn
    ) internal pure returns (uint112) {
        return ((uint256(reserveOut) * amountIn) / (uint256(reserveIn) + amountIn)).toUint112();
    }

    // given a price and a liquidity amount, return the value of that liquidity at the price, rounded up
    function getVirtualReservesAtPrice(
        FixedPoint.uq112x112 memory price,
        uint256 liquidity,
        bool roundUp
    ) internal pure returns (uint112 reserve0, uint112 reserve1) {
        if (liquidity == 0) return (0, 0);

        uint8 safeShiftBits = ((255 - BitMath.mostSignificantBit(price._x)) / 2) * 2;

        uint256 priceScaled = uint256(price._x) << safeShiftBits; // price * 2**safeShiftBits
        uint256 priceScaledRoot = Babylonian.sqrt(priceScaled); // sqrt(priceScaled)
        bool roundUpRoot = priceScaledRoot**2 < priceScaled; // flag for whether priceScaledRoot needs to be rounded up

        uint256 scaleFactor = uint256(1) << (56 + safeShiftBits / 2); // compensate for q112 and shifted bits under root

        // calculate amount0 := liquidity / sqrt(price) and amount1 := liquidity * sqrt(price)
        if (roundUp) {
            reserve0 = mulDivRoundingUp(liquidity, scaleFactor, priceScaledRoot).toUint112();
            reserve1 = mulDivRoundingUp(liquidity, priceScaledRoot + (roundUpRoot ? 1 : 0), scaleFactor).toUint112();
        } else {
            reserve0 = FullMath.mulDiv(liquidity, scaleFactor, priceScaledRoot + (roundUpRoot ? 1 : 0)).toUint112();
            reserve1 = FullMath.mulDiv(liquidity, priceScaledRoot, scaleFactor).toUint112();
        }
    }

    function getInputToRatio(
        uint112 reserve0,
        uint112 reserve1,
        uint112 liquidity,
        FixedPoint.uq112x112 memory priceTarget, // always reserve1/reserve0
        uint16 lpFee,
        bool zeroForOne
    ) internal pure returns (uint112 amountIn, uint112 amountOut) {
        // estimate value of reserves at target price, rounding up
        (uint112 reserve0Target, uint112 reserve1Target) = getVirtualReservesAtPrice(priceTarget, liquidity, true);

        (amountIn, amountOut) = zeroForOne
            ? (reserve0Target - reserve0, reserve1 - reserve1Target)
            : (reserve1Target - reserve1, reserve0 - reserve0Target);

        // scale amountIn by the current fee (rounding up)
        amountIn = mulDivRoundingUp(amountIn, LP_FEE_BASE, LP_FEE_BASE - lpFee).toUint112();

        return (amountIn, amountOut);
    }
}
