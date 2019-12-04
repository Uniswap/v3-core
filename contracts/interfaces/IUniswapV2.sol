pragma solidity 0.5.12;

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

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function priceCumulative0() external view returns (uint240);
    function blockNumberHalf0() external view returns (uint16);
    function priceCumulative1() external view returns (uint240);
    function blockNumberHalf1() external view returns (uint16);

    function getReserves() external view returns (uint128, uint128);
    function readOracleBlockNumber() external view returns (uint32);

    function getInputPrice(uint inputAmount, uint inputReserve, uint outputReserve) external pure returns (uint);

    function mintLiquidity(address recipient) external returns (uint liquidity);
    function burnLiquidity(address recipient) external returns (uint amount0, uint amount1);
    function unsafeRageQuit0(address recipient) external returns (uint amountToken1);
    function unsafeRageQuit1(address recipient) external returns (uint amountToken0);
    function swap0(address recipient) external returns (uint amountToken1);
    function swap1(address recipient) external returns (uint amountToken0);
    function sync() external;
}
