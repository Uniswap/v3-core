// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

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
}
