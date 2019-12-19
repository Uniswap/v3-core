pragma solidity 0.5.14;

interface IUniswapV2Factory {
    event ExchangeCreated(address indexed token0, address indexed token1, address exchange, uint256 exchangeNumber);

    function exchangeBytecode() external view returns (bytes memory);
    function factoryOwner() external view returns (address);
    function feeRecipient() external view returns (address);

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);
    function getExchange(address tokenA, address tokenB) external view returns (address exchange);
    function getTokens(address exchange) external view returns (address token0, address token1);
    function exchanges(uint) external view returns (address exchange);
    function exchangesCount() external view returns (uint);

    function createExchange(address tokenA, address tokenB) external returns (address exchange);
}
