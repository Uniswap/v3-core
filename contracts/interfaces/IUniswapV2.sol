pragma solidity 0.5.12;

interface IUniswapV2 {
    event LiquidityMinted(
        address indexed sender, address indexed recipient, uint256 liquidity, uint128 amountToken0, uint128 amountToken1
    );
    event LiquidityBurned(
        address indexed sender, address indexed recipient, uint256 liquidity, uint128 amountToken0, uint128 amountToken1
    );
    event Swap(
        address indexed sender, address indexed recipient, address input, uint128 amountInput, uint128 amountOutput
    );

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function getReserves() external view returns (uint128, uint128);
    function getReservesCumulative() external view returns (uint128, uint128);

    function getAmountOutput(
        uint128 amountInput, uint128 reserveInput, uint128 reserveOutput
    ) external pure returns (uint128 amountOutput);

    function mintLiquidity(address recipient) external returns (uint256 liquidity);
    function burnLiquidity(address recipient) external returns (uint128 amountToken0, uint128 amountToken1);
    function swap(address input, address recipient) external returns (uint128 amountOutput);
}
