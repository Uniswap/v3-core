pragma solidity 0.5.12;

interface IUniswapV2 {
    event Swap(
        address indexed input,
        address indexed sender,
        address indexed recipient,
        uint256 amountInput,
        uint256 amountOutput
    );
    event LiquidityMinted(
        address indexed sender,
        address indexed recipient,
        uint256 liquidity,
        uint256 amountToken0,
        uint256 amountToken1
    );
    event LiquidityBurned(
        address indexed sender,
        address indexed recipient,
        uint256 liquidity,
        uint256 amountToken0,
        uint256 amountToken1
    );

    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function getAmountOutput(
        uint256 amountInput,
        uint256 reserveInput,
        uint256 reserveOutput
    ) external pure returns (uint256 amountOutput);

    function initialize(address _token0, address _token1, uint256 chainId) external;

    function mintLiquidity(address recipient) external returns (uint256 liquidity);
    function burnLiquidity(
        uint256 liquidity,
        address recipient
    ) external returns (uint256 amountToken0, uint256 amountToken1);
    function swap(address input, address recipient) external returns (uint256 amountOutput);
}
