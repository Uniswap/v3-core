pragma solidity 0.5.12;

interface IUniswapV2 {
    event LiquidityMinted(
        address indexed sender,
        address indexed recipient,
        uint amountToken0,
        uint amountToken1,
        uint128 reserveToken0,
        uint128 reserveToken1,
        uint liquidity
    );
    event LiquidityBurned(
        address indexed sender,
        address indexed recipient,
        uint amountToken0,
        uint amountToken1,
        uint128 reserveToken0,
        uint128 reserveToken1,
        uint liquidity
    );
    event Swap(
        address indexed sender,
        address indexed recipient,
        uint amountToken0,
        uint amountToken1,
        uint128 reserveToken0,
        uint128 reserveToken1,
        address input
    );

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function getReserves() external view returns (uint128, uint128);
    function readOraclePricesAccumulated() external view returns (uint240, uint240);
    function readOracleBlockNumber() external view returns (uint32);
    function consultOracle() external view returns (uint240, uint240);

    function getInputPrice(uint inputAmount, uint inputReserve, uint outputReserve) external pure returns (uint);

    function mintLiquidity(address recipient) external returns (uint liquidity);
    function burnLiquidity(address recipient) external returns (uint amountToken0, uint amountToken1);
    function rageQuitToken0(address recipient) external returns (uint amountToken1);
    function rageQuitToken1(address recipient) external returns (uint amountToken0);
    function swapToken0(address recipient) external returns (uint amountToken1);
    function swapToken1(address recipient) external returns (uint amountToken0);
    function sync() external;
}
