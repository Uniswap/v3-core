// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV3PairImmutables {
    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function fee() external view returns (uint24);

    function tickSpacing() external view returns (int24);

    function minTick() external view returns (int24);

    function maxTick() external view returns (int24);

    function maxLiquidityPerTick() external view returns (uint128);
}
