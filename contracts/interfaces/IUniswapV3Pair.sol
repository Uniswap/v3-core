// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV3Pair {
    function LIQUIDITY_MIN() external pure returns (uint112);

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function reserve0Virtual() external view returns (uint112);
    function reserve1Virtual() external view returns (uint112);
    function blockTimestampLast() external view returns (uint32);

    function tickCurrent() external view returns (int16);
    function virtualSupplies(uint) external view returns (uint112);
}
