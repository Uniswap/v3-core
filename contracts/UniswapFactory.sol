pragma solidity ^0.5.11;
import "./UniswapExchange.sol";
import "./interfaces/IUniswapExchange.sol";


contract UniswapFactory {

  event NewExchange(address indexed token, address indexed exchange);

  uint256 public tokenCount;
  mapping (address => address) public getExchange;
  mapping (address => address) public getToken;
  mapping (uint256 => address) public getTokenWithId;

  function createExchange(address token) public returns (address) {
    require(token != address(0));
    require(getExchange[token] == address(0), 'EXCHANGE_EXISTS');
    UniswapExchange exchange = new UniswapExchange(token);
    getExchange[token] = address(exchange);
    getToken[address(exchange)] = token;
    uint256 tokenId = tokenCount + 1;
    tokenCount = tokenId;
    getTokenWithId[tokenId] = token;
    emit NewExchange(token, address(exchange));
    return address(exchange);
  }
}
