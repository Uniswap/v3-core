pragma solidity 0.5.13;

interface IUniswapV2 {
    event LiquidityMinted(
        address indexed sender, address indexed recipient,
        uint amount0, uint amount1,
        uint128 reserve0, uint128 reserve1,
        uint liquidity
    );
    event LiquidityBurned(
        address indexed sender, address indexed recipient,
        uint amount0, uint amount1,
        uint128 reserve0, uint128 reserve1,
        uint liquidity
    );
    event Swap(
        address indexed sender, address indexed recipient,
        uint amount0, uint amount1,
        uint128 reserve0, uint128 reserve1,
        address input
    );

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function reserve0() external view returns (uint128);
    function reserve1() external view returns (uint128);

    function priceCumulative0() external view returns (uint);
    function priceCumulative1() external view returns (uint);
    function priceCumulative0Overflow() external view returns (uint64);
    function priceCumulative1Overflow() external view returns (uint64);
    function blockNumber() external view returns (uint64);

    function getInputPrice(uint inputAmount, uint inputReserve, uint outputReserve) external pure returns (uint);

    function mintLiquidity(address recipient) external returns (uint liquidity);
    function burnLiquidity(address recipient) external returns (uint amount0, uint amount1);
    function swap0(address recipient) external returns (uint amount1);
    function swap1(address recipient) external returns (uint amount0);
    function sync() external;
}
