// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

interface IUniswapV3PairEvents {
    event Initialized(uint160 sqrtPrice, int24 tick);
    event Mint(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        address payer,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );
    event Collect(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        address recipient,
        uint128 amount0,
        uint128 amount1
    );
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        address recipient,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );
    event Swap(
        address indexed payer,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPrice,
        int24 tick
    );
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );
    event ObservationCardinalityIncreased(uint16 observationCardinalityOld, uint16 observationCardinalityNew);
    event FeeProtocolChanged(uint8 feeProtocolOld, uint8 feeProtocolNew);
    event CollectProtocol(address indexed recipient, uint128 amount0, uint128 amount1);
}
