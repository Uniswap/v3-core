// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

interface IUniswapV3Pair {
    event Initialized(uint256 amount0, uint256 amount1, int16 tick, uint8 feeVote);
    // todo: liquidityDelta or liquidity?
    event PositionSet(address owner, int16 tickLower, int16 tickUpper, uint8 feeVote, int112 liquidityDelta);

    // constants
    function NUM_FEE_OPTIONS() external pure returns (uint8);

    function LIQUIDITY_MIN() external pure returns (uint112);

    function TOKEN_MIN() external pure returns (uint8);

    // immutables
    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    // variables/state
    function reserve0Virtual() external view returns (uint112);

    function reserve1Virtual() external view returns (uint112);

    function blockTimestampLast() external view returns (uint32);

    function tickCurrent() external view returns (int16);

    function virtualSupplies(uint256) external view returns (uint112);

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    // derived state
    function getFee() external view returns (uint16 fee);

    function getVirtualSupply() external view returns (uint112 virtualSupply);

    function getCumulativePrices() external view returns (uint256 price0Cumulative, uint256 price1Cumulative);

    // swapping
    function swap0For1(
        uint112 amount0In,
        address to,
        bytes calldata data
    ) external returns (uint112 amount1Out);

    function swap1For0(
        uint112 amount1In,
        address to,
        bytes calldata data
    ) external returns (uint112 amount0Out);

    // called by feeToSetter of the factory
    function feeTo() external view returns (address);

    function setFeeTo(address) external;

    // allows the factory feeToSetter address to recover any tokens other than token0 and token1 held by the contract
    function recover(
        address token,
        address to,
        uint256 amount
    ) external;
}
