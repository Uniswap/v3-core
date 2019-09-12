pragma solidity ^0.5.11;
import "./UniswapERC20.sol";ss

contract UniswapERC20Factory {

  event NewERC20Exchange(address indexed tokenA, address indexed tokenB, address indexed exchange);

  struct Pair {
    address tokenA;
    address tokenB;
  }

  uint256 public exchangeCount;
  mapping (address => mapping(address => address)) internal setExchange;
  mapping (address => Pair) public getPair;
  mapping (uint256 => address) public getExchangeWithId;


  function createExchange(address token1, address token2) public returns (address) {
    require(token1 != address(0) && token2 != address(0) && token1 != token2);
    require(setExchange[token1][token2] == address(0), 'EXCHANGE_EXISTS');

    address tokenA = token1;
    address tokenB = token2;
    if(uint256(token2) < uint256(token1)) {
      tokenA = token2;
      tokenB = token1;
    }

    UniswapERC20 exchange = new UniswapERC20(tokenA, tokenB);
    setExchange[tokenA][tokenB] = address(exchange);
    getPair[address(exchange)].tokenA = tokenA;
    getPair[address(exchange)].tokenB = tokenB;

    uint256 exchangeId = exchangeCount + 1;
    exchangeCount = exchangeId;
    getExchangeWithId[exchangeId] = address(exchange);

    emit NewERC20Exchange(tokenA, tokenB, address(exchange));
    return address(exchange);
  }
}
