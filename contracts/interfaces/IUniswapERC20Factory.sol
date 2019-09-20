pragma solidity ^0.5.11;

interface IUniswapERC20Factory {

  event NewERC20Exchange(address indexed tokenA, address indexed tokenB, address indexed exchange);

  function createExchange(address token1, address token2) external returns (address);
}
