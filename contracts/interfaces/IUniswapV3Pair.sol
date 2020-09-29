// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV3Pair {
    function LIQUIDITY_MIN() external pure returns (uint112);
    function TOKEN_MIN() external pure returns (uint8);

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function reserve0Virtual() external view returns (uint112);
    function reserve1Virtual() external view returns (uint112);
    function blockTimestampLast() external view returns (uint32);

    function tickCurrent() external view returns (int16);
    function virtualSupplies(uint) external view returns (uint112);

    event Initialized(uint amount0, uint amount1, int16 tick, uint8 feeVote);
    event PositionSet(address owner, int16 tickLower, int16 tickUpper, uint8 feeVote, int112 liquidityDelta);
}
