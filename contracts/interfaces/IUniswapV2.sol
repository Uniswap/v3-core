pragma solidity 0.5.15;

interface IUniswapV2 {
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address indexed sender, address indexed tokenIn, uint amountIn, uint amountOut, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function reserve0() external view returns (uint112);
    function reserve1() external view returns (uint112);
    function blockNumberLast() external view returns (uint32);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(address tokenIn, uint amountOut, address to) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external; // only called once by the factory on deploy
}
