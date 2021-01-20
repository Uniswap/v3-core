// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './FullMath.sol';
import './FixedPoint128.sol';
import './LiquidityMath.sol';

// positions represent an owner account's liquidity at a given lower/upper tick combination, and store additional state
// for tracking fees owed to the position.
library Position {
    // info stored for each user's position
    struct Info {
        // the amount of liquidity owned by this position
        uint128 liquidity;
        // fee growth per unit of liquidity as of the last update to liquidity or fees owed
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // the fees owed to the position owner in token0/token1
        uint256 feesOwed0;
        uint256 feesOwed1;
    }

    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Position.Info storage position) {
        position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    // updates the position with the liquidity delta, returning the owed fees
    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128,
        uint8 feeProtocol
    ) internal returns (uint256 protocolFees0, uint256 protocolFees1) {
        if (liquidityDelta == 0) {
            // disallow pokes for 0 liquidity positions
            require(self.liquidity > 0, 'NP');
        }

        // calculate accumulated fees
        uint256 feesOwed0 =
            FullMath.mulDiv(feeGrowthInside0X128 - self.feeGrowthInside0LastX128, self.liquidity, FixedPoint128.Q128);
        uint256 feesOwed1 =
            FullMath.mulDiv(feeGrowthInside1X128 - self.feeGrowthInside1LastX128, self.liquidity, FixedPoint128.Q128);

        // collect protocol fee
        if (feeProtocol > 0) {
            uint256 fee0 = feesOwed0 / feeProtocol;
            feesOwed0 -= fee0;
            protocolFees0 = fee0;

            uint256 fee1 = feesOwed1 / feeProtocol;
            feesOwed1 -= fee1;
            protocolFees1 = fee1;
        }

        uint128 liquidityNext = LiquidityMath.addDelta(self.liquidity, liquidityDelta);

        // update the position
        self.liquidity = liquidityNext;
        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;
        self.feesOwed0 += feesOwed0;
        self.feesOwed1 += feesOwed1;

        // clear position data that is no longer needed
        if (liquidityDelta < 0 && liquidityNext == 0) {
            delete self.feeGrowthInside0LastX128;
            delete self.feeGrowthInside1LastX128;
        }
    }
}
