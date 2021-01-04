// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

library Position {
    struct Info {
        uint128 liquidity;
        // fee growth per unit of liquidity as of the last modification
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // the fees owed to the position owner in token0/token1
        uint256 feesOwed0;
        uint256 feesOwed1;
    }

    function getPosition(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Position.Info storage position) {
        position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }
}
