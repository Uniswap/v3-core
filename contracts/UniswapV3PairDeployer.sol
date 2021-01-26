// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import './interfaces/IUniswapV3PairDeployer.sol';

import './UniswapV3Pair.sol';

contract UniswapV3PairDeployer is IUniswapV3PairDeployer {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
        uint160 sqrtPriceX96;
    }

    Parameters public override parameters;

    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing,
        uint160 sqrtPriceX96
    ) internal returns (address pair) {
        parameters = Parameters({
            factory: factory,
            token0: token0,
            token1: token1,
            fee: fee,
            tickSpacing: tickSpacing,
            sqrtPriceX96: sqrtPriceX96
        });
        pair = address(new UniswapV3Pair{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }
}
