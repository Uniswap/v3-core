// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

interface IUniswapV3Pair {
    event Initialized(int16 tick);

    // event PositionSet(address owner, int16 tickLower, int16 tickUpper, uint8 feeVote, int112 liquidityDelta);

    // constants
    function NUM_FEE_OPTIONS() external pure returns (uint8);

    function FEE_OPTIONS(uint8) external pure returns (uint16);

    // immutables
    function factory() external pure returns (address);

    function token0() external pure returns (address);

    function token1() external pure returns (address);

    // variables/state
    function feeTo() external view returns (address);

    function blockTimestampLast() external view returns (uint64);

    function feeFloor() external view returns (uint16);

    function liquidityCurrent(uint256) external view returns (uint128);

    function tickBitMap(uint256) external view returns (uint256);

    function tickCurrent() external view returns (int16);

    function priceCurrent() external view returns (uint256);

    function feeGrowthGlobal0() external view returns (uint256);

    function feeGrowthGlobal1() external view returns (uint256);

    function feeToFees0() external view returns (uint256);

    function feeToFees1() external view returns (uint256);

    // derived state
    function isInitialized() external view returns (bool);

    function getLiquidity() external view returns (uint128);

    function getFee() external view returns (uint16);

    //    function getCumulativePrices()
    //        external
    //        view
    //        returns (FixedPoint.uq144x112 memory price0Cumulative, FixedPoint.uq144x112 memory price1Cumulative);

    // initialize the pair
    function initialize(int16 tick) external;

    function setPosition(
        int16 tickLower,
        int16 tickUpper,
        uint8 feeVote,
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

    // allows the factory feeToSetter address to recover any tokens other than token0 and token1 held by the contract
    function recover(
        address token,
        address to,
        uint256 amount
    ) external;
}
