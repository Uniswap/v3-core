pragma solidity 0.5.15;

interface IUniswapV2 {
    event Make(address indexed sender, uint amount0, uint amount1);
    event Made(address indexed sender, uint amount0, uint amount1);
    event Move(address indexed sender, address indexed tokenIn, uint amountIn, uint amountOut);
    event Sync(uint112 reserve0, uint112 reserve1);

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function reserve0() external view returns (uint112);
    function reserve1() external view returns (uint112);
    function blockNumberLast() external view returns (uint32);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);

    function make() external returns (uint liquidity);
    function made() external returns (uint amount0, uint amount1);
    function move(address tokenIn, uint amountOut) external;
    function skim() external;
    function sync() external;

    function initialize(address, address) external; // only called once by the factory on deploy
}
