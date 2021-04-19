// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import './UniswapV3Pool.sol';

library UniswapV3PoolDeployer {
    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    function deploy(
        address token0,
        address token1,
        uint24 fee
    ) public returns (address pool) {
        pool = address(new UniswapV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
    }
}
