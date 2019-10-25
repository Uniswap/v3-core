pragma solidity 0.5.12;

interface IUniswapV2Factory {
    event ExchangeCreated(address indexed token0, address indexed token1, address exchange, uint256 exchangeCount);

    function exchangeBytecode() external view returns (bytes memory);
    function exchangeCount() external view returns (uint256);
    function getTokens(address exchange) external view returns (address token0, address token1);
    function getExchange(address tokenA, address tokenB) external view returns (address exchange);

    function createExchange(address tokenA, address tokenB) external returns (address exchange);
}
