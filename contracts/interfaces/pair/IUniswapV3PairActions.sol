// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV3PairActions {
    // initialize the pair
    function initialize(uint160 sqrtPriceX96) external;

    // mint some liquidity to an address
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external;

    // collect fees
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    // burn the sender's liquidity
    function burn(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimit,
        bytes calldata data
    ) external;

    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}
