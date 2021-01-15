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
        uint256 amount0,
        uint256 amount1
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
    event FeeProtocolChanged(uint8 indexed feeProtocolOld, uint8 indexed feeProtocolNew);
    event CollectProtocol(address indexed recipient, uint256 amount0, uint256 amount1);
}
