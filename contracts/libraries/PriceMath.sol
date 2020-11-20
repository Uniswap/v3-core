// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/FullMath.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';
import '@uniswap/lib/contracts/libraries/BitMath.sol';

import './SafeCast.sol';

library PriceMath {
    using SafeMath for uint256;
    using SafeCast for uint256;

    uint16 public constant LP_FEE_BASE = 1e4; // i.e. 10k bips, 100%

    function mulDivRoundingUp(
        uint256 x,
        uint256 y,
        uint256 d
    ) internal pure returns (uint256) {
        return FullMath.mulDiv(x, y, d) + (mulmod(x, y, d) > 0 ? 1 : 0);
    }

    // amountIn here is assumed to have already been discounted by the fee
    function getAmountOut(
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 amountIn
    ) internal pure returns (uint256 amountOut) {
        amountOut = FullMath.mulDiv(reserveOut, amountIn, reserveIn.add(amountIn));
    }

    // given a price and a liquidity amount, return the value of that liquidity at the price, rounded up
    function getVirtualReservesAtPrice(
        FixedPoint.uq112x112 memory price,
        uint112 liquidity,
        bool roundUp
    ) internal pure returns (uint256 reserve0, uint256 reserve1) {
        if (liquidity == 0) return (0, 0);

        uint8 safeShiftBits = ((255 - BitMath.mostSignificantBit(price._x)) / 2) * 2;

        uint256 priceScaled = uint256(price._x) << safeShiftBits; // price * 2**safeShiftBits
        uint256 priceScaledRoot = Babylonian.sqrt(priceScaled); // sqrt(priceScaled)
        bool roundUpRoot = priceScaledRoot**2 < priceScaled; // flag for whether priceScaledRoot needs to be rounded up

        uint256 scaleFactor = uint256(1) << (56 + safeShiftBits / 2); // compensate for q112 and shifted bits under root

        // calculate amount0 := liquidity / sqrt(price) and amount1 := liquidity * sqrt(price)
        if (roundUp) {
            reserve0 = mulDivRoundingUp(liquidity, scaleFactor, priceScaledRoot);
            reserve1 = mulDivRoundingUp(liquidity, priceScaledRoot + (roundUpRoot ? 1 : 0), scaleFactor);
        } else {
            reserve0 = FullMath.mulDiv(liquidity, scaleFactor, priceScaledRoot + (roundUpRoot ? 1 : 0));
            reserve1 = FullMath.mulDiv(liquidity, priceScaledRoot, scaleFactor);
        }
    }

    function getInputToRatio(
        uint256 reserve0,
        uint256 reserve1,
        uint112 liquidity,
        FixedPoint.uq112x112 memory priceTarget, // always reserve1/reserve0
        uint16 lpFee,
        bool zeroForOne
    ) internal pure returns (uint256 amountIn, uint256 amountOut) {
        // estimate value of reserves at target price, rounding up
        (uint256 reserve0Target, uint256 reserve1Target) = getVirtualReservesAtPrice(priceTarget, liquidity, true);

        (amountIn, amountOut) = zeroForOne
            ? (reserve0Target - reserve0, reserve1 - reserve1Target)
            : (reserve1Target - reserve1, reserve0 - reserve0Target);

        // scale amountIn by the current fee (rounding up)
        amountIn = mulDivRoundingUp(amountIn, LP_FEE_BASE, LP_FEE_BASE - lpFee);
    }

    function getAmount0Delta(
        FixedPoint.uq112x112 memory priceLower,
        FixedPoint.uq112x112 memory priceUpper,
        int112 liquidity
    ) internal pure returns (int256) {
        if (liquidity == 0) return 0;

        uint8 safeShiftBits = ((255 - BitMath.mostSignificantBit(priceUpper._x)) / 2) * 2;
        if (liquidity < 0) safeShiftBits -= 2; // ensure that our denominator won't overflow

        uint256 priceLowerScaled = uint256(priceLower._x) << safeShiftBits; // priceLower * 2**safeShiftBits
        uint256 priceLowerScaledRoot = Babylonian.sqrt(priceLowerScaled); // sqrt(priceLowerScaled)
        bool roundUpLower = priceLowerScaledRoot**2 < priceLowerScaled;

        uint256 priceUpperScaled = uint256(priceUpper._x) << safeShiftBits; // priceUpper * 2**safeShiftBits
        uint256 priceUpperScaledRoot = Babylonian.sqrt(priceUpperScaled); // sqrt(priceUpperScaled)
        bool roundUpUpper = priceUpperScaledRoot**2 < priceUpperScaled;

        // calculate liquidity * (sqrt(priceUpper) - sqrt(priceLower)) / sqrt(priceUpper) * sqrt(priceLower)
        if (liquidity > 0) {
            uint256 amount0 = PriceMath.mulDivRoundingUp(
                uint256(liquidity) << (safeShiftBits / 2), // * 2**(SSB/2)
                (priceUpperScaledRoot + (roundUpUpper ? 1 : 0) - priceLowerScaledRoot) << 56, // * 2**56
                priceLowerScaledRoot * priceUpperScaledRoot
            );
            return amount0.toInt256();
        }
        uint256 amount0 = FullMath.mulDiv(
            uint256(uint112(-liquidity)) << (safeShiftBits / 2), // * 2**(SSB/2)
            priceUpperScaledRoot.sub(priceLowerScaledRoot + (roundUpLower ? 1 : 0)) << 56, // * 2**56
            (priceLowerScaledRoot + (roundUpLower ? 1 : 0)) * (priceUpperScaledRoot + (roundUpUpper ? 1 : 0))
        );
        return -amount0.toInt256();
    }

    function getAmount1Delta(
        FixedPoint.uq112x112 memory priceLower,
        FixedPoint.uq112x112 memory priceUpper,
        int112 liquidity
    ) internal pure returns (int256) {
        if (liquidity == 0) return 0;

        uint8 safeShiftBits = ((255 - BitMath.mostSignificantBit(priceUpper._x)) / 2) * 2;

        uint256 priceLowerScaled = uint256(priceLower._x) << safeShiftBits; // priceLower * 2**safeShiftBits
        uint256 priceLowerScaledRoot = Babylonian.sqrt(priceLowerScaled); // sqrt(priceLowerScaled)
        bool roundUpLower = priceLowerScaledRoot**2 < priceLowerScaled;

        uint256 priceUpperScaled = uint256(priceUpper._x) << safeShiftBits; // priceUpper * 2**safeShiftBits
        uint256 priceUpperScaledRoot = Babylonian.sqrt(priceUpperScaled); // sqrt(priceUpperScaled)
        bool roundUpUpper = priceUpperScaledRoot**2 < priceUpperScaled;

        // calculate liquidity * (sqrt(priceUpper) - sqrt(priceLower))
        if (liquidity > 0) {
            uint256 amount1 = PriceMath.mulDivRoundingUp(
                uint256(liquidity),
                priceUpperScaledRoot + (roundUpUpper ? 1 : 0) - priceLowerScaledRoot,
                uint256(1) << (56 + safeShiftBits / 2)
            );
            return amount1.toInt256();
        }
        uint256 amount1 = FullMath.mulDiv(
            uint256(uint112(-liquidity)),
            priceUpperScaledRoot.sub(priceLowerScaledRoot + (roundUpLower ? 1 : 0)),
            uint256(1) << (56 + safeShiftBits / 2)
        );
        return -amount1.toInt256();
    }
}
