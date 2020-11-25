// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

interface IUniswapV3Pair {
    event Initialized(int24 tick);

    // event PositionSet(address owner, int24 tickLower, int24 tickUpper, uint8 feeVote, int112 liquidityDelta);

    // immutables
    function factory() external pure returns (address);

    function token0() external pure returns (address);

    function token1() external pure returns (address);

    function fee() external pure returns (uint24);

    // variables/state
    function feeTo() external view returns (address);

    function blockTimestampLast() external view returns (uint32);

    function liquidityCurrent() external view returns (uint128);

    function tickBitMap(uint256) external view returns (uint256);

    function tickCurrent() external view returns (int24);

    function priceCurrent() external view returns (uint256);

    function feeGrowthGlobal0() external view returns (uint256);

    function feeGrowthGlobal1() external view returns (uint256);

    function feeToFees0() external view returns (uint256);

    function feeToFees1() external view returns (uint256);

    // derived state
    function isInitialized() external view returns (bool);

    // initialize the pair
    function initialize(int24 tick) external;

    function setPosition(
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta
    ) external returns (int256 amount0, int256 amount1);

    // swapping
    function swap0For1(
        uint256 amount0In,
        address to,
        bytes calldata data
    ) external returns (uint256 amount1Out);

    function swap1For0(
        uint256 amount1In,
        address to,
        bytes calldata data
    ) external returns (uint256 amount0Out);

    function setFeeTo(address) external;

    // allows the factory owner address to recover any tokens other than token0 and token1 held by the contract
    function recover(
        address token,
        address to,
        uint256 amount
    ) external;
}
