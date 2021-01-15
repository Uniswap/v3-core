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
        int24 tickLower,
        int24 tickUpper,
        address recipient,
        uint256 amount0Requested,
        uint256 amount1Requested
    ) external returns (uint256 amount0, uint256 amount1);

    // burn the sender's liquidity
    function burn(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    function swap(
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimit,
        address recipient,
        bytes calldata data
    ) external;

    function setFeeProtocol(uint8) external;

    // allows factory owner to collect protocol fees
    function collectProtocol(
        address recipient,
        uint256 amount0Requested,
        uint256 amount1Requested
    ) external returns (uint256 amount0, uint256 amount1);
}
