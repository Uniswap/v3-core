// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV3PairState {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint8 feeProtocol,
            bool unlocked
        );

    function tickBitmap(int16) external view returns (uint256);

    function feeGrowthGlobal0X128() external view returns (uint256);

    function feeGrowthGlobal1X128() external view returns (uint256);

    function liquidity() external view returns (uint128);

    function protocolFees0() external view returns (uint256);

    function protocolFees1() external view returns (uint256);

    function observations(uint256)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 liquidityCumulative,
            bool initialized
        );
}
