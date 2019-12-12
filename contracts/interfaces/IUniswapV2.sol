pragma solidity 0.5.14;

interface IUniswapV2 {
    event ReservesUpdated(uint112 reserve0, uint112 reserve1);
    event LiquidityMinted(address indexed sender, uint amount0, uint amount1);
    event LiquidityBurned(address indexed sender, address indexed recipient, uint amount0, uint amount1);
    event Swap(address indexed sender, address indexed recipient, address indexed input, uint amount0, uint amount1);

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function reserve0() external view returns (uint112);
    function reserve1() external view returns (uint112);
    function blockNumberLast() external view returns (uint32);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);

    function getInputPrice(uint inputAmount, uint inputReserve, uint outputReserve) external pure returns (uint);

    function mintLiquidity(address recipient) external returns (uint liquidity);
    function burnLiquidity(address recipient) external returns (uint amount0, uint amount1);
    function swap0(address recipient) external returns (uint amount1);
    function swap1(address recipient) external returns (uint amount0);

    function sync() external;
    function sweep() external;
}
