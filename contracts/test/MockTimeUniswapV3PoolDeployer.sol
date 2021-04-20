// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '../interfaces/IUniswapV3PoolDeployer.sol';

import './MockTimeUniswapV3Pool.sol';

library MockDeployerLib {
    function deploy(
        address token0,
        address token1,
        uint24 fee
    ) public returns (address pool) {
        pool = address(new MockTimeUniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
    }
}

contract MockTimeUniswapV3PoolDeployer is IUniswapV3PoolDeployer {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    Parameters public override parameters;

    event PoolDeployed(address pool);

    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) external returns (address pool) {
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        pool = MockDeployerLib.deploy(token0, token1, fee);
        emit PoolDeployed(pool);
        delete parameters;
    }
}
