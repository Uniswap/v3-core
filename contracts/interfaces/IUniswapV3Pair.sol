// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV3Pair {
    function LIQUIDITY_MIN() external pure returns (uint112);
    function FEE_VOTE_MAX() external pure returns (uint16);

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function reserve0() external view returns (uint112);
    function reserve1() external view returns (uint112);
    function blockTimestampLast() external view returns (uint32);

    function tickCurrent() external view returns (int16);
    function liquidityCurrent() external view returns (uint112);

    function kLast() external view returns (uint224);
}
