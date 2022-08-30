pragma solidity ^0.8.0;

import './interfaces/pool/IUniswapV3PoolActions.sol';
import './interfaces/pool/IUniswapV3PoolState.sol';
import './libraries/TickMath.sol';
// import './libraries/LiquidityAmounts.sol';

contract TestPoolInitialize {

    function initialize_(address addr, uint160 sqrtPrice) external {
        IUniswapV3PoolActions(addr).initialize(sqrtPrice);
    }

  //   function mint_(
  //   address addr,
  //   address recipient,
  //   int24 tickLower,
  //   int24 tickUpper,
  //   uint128 amount
  // ) external returns (uint256 amount0, uint256 amount1) {
  //       bytes memory data = 'Test';
  //       return IUniswapV3PoolActions(addr).mint(recipient, tickLower, tickUpper, amount, data);
        
  // }

  // function slot0_(address addr) external
  //       view
  //       returns (
  //           uint160 sqrtPriceX96,
  //           int24 tick,
  //           uint16 observationIndex,
  //           uint16 observationCardinality,
  //           uint16 observationCardinalityNext,
  //           uint8 feeProtocol,
  //           bool unlocked
  //       ) {
  //   return IUniswapV3PoolState(addr).slot0();
  // }

  // function liquidity_(address addr) external view returns (uint128) {
  //   return IUniswapV3PoolState(addr).liquidity();
  // }

  // function addLiquidity(
  //   address pool,
  //   address token0, 
  //   address token1, 
  //   address recipient,
  //   int24 tickLower,
  //   int24 tickUpper,
  //   uint256 amount0Desired,
  //   uint256 amount1Desired) external returns (uint128 liquidity, uint amount0, uint amount1) {

  //     (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3PoolState(pool).slot0();
  //     uint160 sqrtRationAX96 = TickMath.getSqrtRatioAtTick(tickLower);
  //     uint160 sqrtRationBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

  //     liquidity = LiquidityAmounts.getLiquidityForAmounts(
  //       sqrtRatioX96, 
  //       sqrtRatioAX96, 
  //       sqrtRatioBX96,
  //       amount0Desired, 
  //       amount1Desired);
      
  //     (amount0, amount1) = mint_(pool,recipient,tickLower,tickUpper,liquidity);
    // }

}