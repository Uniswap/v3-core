// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

import './FullMath.sol';
import './FixedPoint128.sol';
import './LiquidityMath.sol';

/// @title Position
/// @notice Positions represent an owner address' liquidity between a lower and upper tick boundary
/// @dev Positions store additional state for tracking fees owed to the position
library Position {
    // the minimum time after a mint at which fees earned are no longer penalized with linear decay if exercised
    uint256 private constant feePenaltyThreshold = 1 minutes;
    // the minimum percentage which mints must increase a position's liquidity by
    // represented as a numerator (x/100)%
    uint256 private constant minimumLiquidityIncrease = 101;

    // info stored for each user's position
    struct Info {
        // the amount of liquidity owned by this position
        uint128 liquidity;
        // the most recent time that liquidity was added to this position
        uint32 lastAddedTo;
        // fee growth per unit of liquidity as of the last update to liquidity or fees owed
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // the fees owed to the position owner in token0/token1
        uint128 feesOwed0;
        uint128 feesOwed1;
    }

    /// @notice Returns the Info struct of a position, given an owner and position boundaries
    /// @param self The mapping containing all user positions
    /// @param owner The address of the position owner
    /// @param tickLower The lower tick boundary of the position
    /// @param tickUpper The upper tick boundary of the position
    /// @return position The position info struct of the given owners' position
    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Position.Info storage position) {
        position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    /// @notice Credits accumulated fees to a user's position
    /// @param self The mapping containing all user positions
    /// @param liquidityDelta The change in pair liquidity as a result of the position update
    /// @param feeGrowthInside0X128 The all-time fee growth in token0, per unit of liquidity, inside the position's tick boundaries
    /// @param feeGrowthInside1X128 The all-time fee growth in token1, per unit of liquidity, inside the position's tick boundaries
    /// Returns protocolFees0 new protocol fees in token0 that were collected
    /// Returns protocolFees1 new protocol fees in token1 that were collected
    function update(
        Info storage self,
        int128 liquidityDelta,
        uint32 time,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal returns (uint128 protocolFees0, uint128 protocolFees1) {
        Info memory _self = self;

        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            require(_self.liquidity > 0, 'NP'); // disallow pokes for 0 liquidity positions
            liquidityNext = _self.liquidity;
        } else {
            liquidityNext = LiquidityMath.addDelta(_self.liquidity, liquidityDelta);
        }

        // calculate accumulated fees
        uint128 feesOwed0 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside0X128 - _self.feeGrowthInside0LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );
        uint128 feesOwed1 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside1X128 - _self.feeGrowthInside1LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );

        // update the position
        if (liquidityDelta != 0) self.liquidity = liquidityNext;
        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;
        if (feesOwed0 > 0 || feesOwed1 > 0) {
            // overflow is safe
            uint32 elapsed = time - self.lastAddedTo;
            if (elapsed < feePenaltyThreshold) {
                // implement the fee penalty (rounding in favor of the protocol)
                uint128 feesOwed0New = uint128((uint256(feesOwed0) * elapsed) / feePenaltyThreshold);
                uint128 feesOwed1New = uint128((uint256(feesOwed1) * elapsed) / feePenaltyThreshold);
                protocolFees0 = feesOwed0 - feesOwed0New;
                protocolFees1 = feesOwed1 - feesOwed1New;
                feesOwed0 = feesOwed0New;
                feesOwed1 = feesOwed1New;
            }

            // overflow is acceptable, have to withdraw before you hit type(uint128).max fees
            self.feesOwed0 += feesOwed0;
            self.feesOwed1 += feesOwed1;
        }
        if (liquidityDelta > 0) {
            // ensure that enough new liquidity is being added
            require((uint256(liquidityNext) * 100) / minimumLiquidityIncrease >= _self.liquidity, 'SM');
            // important that this happens after the fee block, which uses self.lastAddedTo
            self.lastAddedTo = time;
        }

        // clear position data that is no longer needed
        if (liquidityNext == 0) {
            delete self.lastAddedTo;
            delete self.feeGrowthInside0LastX128;
            delete self.feeGrowthInside1LastX128;
        }
    }
}
