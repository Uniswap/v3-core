// TODO review, create2
pragma solidity 0.5.12;

import "./UniswapV2.sol";

contract UniswapV2Factory {
    event ExchangeCreated(address indexed token0, address indexed token1, address exchange);

    mapping (address => address) internal exchangeToToken0;
    mapping (address => address) internal exchangeToToken1;
    mapping (address => mapping(address => address)) internal token0ToToken1ToExchange;

    function orderTokens(address tokenA, address tokenB) internal pure returns (address, address) {
        address token0 = tokenA < tokenB ? tokenA : tokenB;
        address token1 = tokenA < tokenB ? tokenB : tokenA;
        return (token0, token1);
    }

    function createExchange(address tokenA, address tokenB) public returns (address) {
        require(tokenA != tokenB, "UniswapV2Factory: INVALID_PAIR");
        require(tokenA != address(0) && tokenB != address(0), "UniswapV2Factory: NO_ZERO_ADDRESS_TOKENS");

        (address token0, address token1) = orderTokens(tokenA, tokenB);

        require(token0ToToken1ToExchange[token0][token1] == address(0), "UniswapV2Factory: EXCHANGE_EXISTS");

        UniswapV2 exchange = new UniswapV2(token0, token1);
        exchangeToToken0[address(exchange)] = token0;
        exchangeToToken1[address(exchange)] = token1;
        token0ToToken1ToExchange[token0][token1] = address(exchange);

        emit ExchangeCreated(token0, token1, address(exchange));

        return address(exchange);
    }

    function getExchange(address tokenA, address tokenB) public view returns (address) {
        (address token0, address token1) = orderTokens(tokenA, tokenB);
        return token0ToToken1ToExchange[token0][token1];
    }

    function getTokens(address exchange) public view returns (address, address) {
        return (exchangeToToken0[exchange], exchangeToToken1[exchange]);
    }
}
