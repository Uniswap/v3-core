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
    }

    /// @inheritdoc IUniswapV3PairDeployer
    Parameters public override parameters;

    /// @dev Deploys a pair with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pair.
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pair) {
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        pair = address(new UniswapV3Pair{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }
}
