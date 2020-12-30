// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.0;

// capable of deploying UniswapV3Pair contracts
interface IUniswapV3PairDeployer {
    // returns the arguments that are normally passed in to the constructor
    function parameters()
        external
        view
        returns (
            address factory,
            address token0,
            address token1,
            uint24 fee,
            int24 tickSpacing
        );

    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) external returns (address pair);
}
