pragma solidity 0.5.12;

interface IUniswapV2Factory {
    event ExchangeCreated(address indexed token0, address indexed token1, address exchange, uint256 exchangeCount);

    function exchangeBytecode() external view returns (bytes memory);
    function exchangeCount() external view returns (uint256);

    function getTokens(address exchange) external view returns (address, address);
    function getExchange(address tokenA, address tokenB) external view returns (address);
    function getOtherTokens(address token) external view returns (address[] memory);
    function getOtherTokensLength(address token) external view returns (uint256);

    function createExchange(address tokenA, address tokenB) external returns (address exchange);
}
