pragma solidity =0.5.16;

interface IUniswapV2Factory {
    event ExchangeCreated(address indexed token0, address indexed token1, address exchange, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getExchange(address tokenA, address tokenB) external view returns (address exchange);
    function allExchanges(uint) external view returns (address exchange);
    function allExchangesLength() external view returns (uint);

    function createExchange(address tokenA, address tokenB) external returns (address exchange);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;    
}
