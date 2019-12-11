pragma solidity 0.5.13;

interface IUniswapV2 {
    event LiquidityMinted(
        address indexed sender,
        address indexed recipient,
        uint amount0,
        uint amount1,
        uint128 reserve0,
        uint128 reserve1,
        uint liquidity
    );
    event LiquidityBurned(
        address indexed sender,
        address indexed recipient,
        uint amount0,
        uint amount1,
        uint128 reserve0,
        uint128 reserve1,
        uint liquidity
    );
    event Swap(
        address indexed sender,
        address indexed recipient,
        uint amount0,
        uint amount1,
        uint128 reserve0,
        uint128 reserve1,
        address input
    );
    event FeeLiquidityMinted(uint liquidity);

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function reserve0() external view returns (uint112);
    function reserve1() external view returns (uint112);
    function blockNumberLast() external view returns (uint32);
    function priceCumulative0Last() external view returns (uint);
    function priceCumulative1Last() external view returns (uint);

    function getInputPrice(uint inputAmount, uint inputReserve, uint outputReserve) external pure returns (uint);

    function mintLiquidity(address recipient) external returns (uint liquidity);
    function burnLiquidity(address recipient) external returns (uint amount0, uint amount1);
    function swap0(address recipient) external returns (uint amount1);
    function swap1(address recipient) external returns (uint amount0);

    function sync() external;
    function sweep() external;
}
