// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.14;

import './interfaces/IUniswapV3PoolDeployer.sol';

import './UniswapV3Pool.sol';

contract UniswapV3PoolDeployer is IUniswapV3PoolDeployer {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    /// @inheritdoc IUniswapV3PoolDeployer
    Parameters public override parameters;

    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The spacing between usable ticks
    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        pool = address(new UniswapV3Pool{salt: hash_stub_1(token0, token1, fee)}());
        delete parameters;
    }

    /// warp-cairo
    /// func CURRENTFUNC(){
    ///    pedersen_ptr: HashBuiltin*,
    ///    range_check_ptr: felt
    ///}(
    ///     token0 : felt,
    ///     token1 : felt,
    ///     fee : felt,
    /// ) -> (res: Uint256):
    ///     from starkware.cairo.common.hash import hash2
    ///     from warplib.maths.utils import felt_to_uint256
    ///     #from warplib.memory import wm_new, wm_write_felt
    ///     let (hash_res_1) = hash2{hash_ptr=pedersen_ptr}(token0, token1)
    ///     let (hash_res_2) = hash2{hash_ptr=pedersen_ptr}(hash_res_1, fee)
    ///     let (res: Uint256) = felt_to_uint256(hash_res_2)
    ///     #let (arr) = wm_new(Uint256(3, 0), Uint256(1,0))
    ///     #wm_write_felt(arr + 2, token0)
    ///     #wm_write_felt(arr + 3, token1)
    ///     #wm_write_felt(arr + 4, fee)
    ///     #let (res) = warp_keccak(arr)
    ///     return (res)
    ///end
    function hash_stub_1(address token0, address token1, uint24 fee) internal view returns (bytes32) {
        // bytes memory x = new bytes(0);
        // keccak256(x);
        return 0;
    }
}
