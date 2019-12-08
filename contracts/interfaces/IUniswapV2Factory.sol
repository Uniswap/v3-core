pragma solidity 0.5.13;

interface IUniswapV2Factory {
    event ExchangeCreated(address indexed token0, address indexed token1, address exchange, uint256 exchangeNumber);

    function exchangeBytecode() external view returns (bytes memory);

    function sortTokens(address tokenA, address tokenB) external pure returns (address, address);
    function getExchange(address tokenA, address tokenB) external view returns (address);
    function getTokens(address exchange) external view returns (address, address);
    function getExchanges() external view returns (address[] memory);
    function getExchangesCount() external view returns (uint);

    function createExchange(address tokenA, address tokenB) external returns (address exchange);
}
