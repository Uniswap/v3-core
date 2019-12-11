pragma solidity 0.5.13;

import "./interfaces/IUniswapV2.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";
import "./token/ERC20.sol";
import "./token/SafeTransfer.sol";

contract UniswapV2 is IUniswapV2, ERC20("Uniswap V2", "UNI-V2", 18, 0), SafeTransfer {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    address public factory;
    address public token0;
    address public token1;

    uint112 public reserve0;
    uint112 public reserve1;
    uint32  public blockNumberLast;
    uint    public priceCumulative0;
    uint    public priceCumulative1;

    uint private invariantLast;

    bool private notEntered = true;
    modifier lock() {
        require(notEntered, "UniswapV2: LOCKED");
        notEntered = false;
        _;
        notEntered = true;
    }

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

    constructor() public {
        factory = msg.sender;
        blockNumberLast = uint32(block.number % 2**32);
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory && token0 == address(0) && token1 == address(0), 'UniswapV2: FORBIDDEN');
        token0 = _token0;
        token1 = _token1;
    }

    function getInputPrice(uint inputAmount, uint inputReserve, uint outputReserve) public pure returns (uint) {
        require(inputReserve > 0 && outputReserve > 0, "UniswapV2: INVALID_VALUE");
        uint amountInputWithFee = inputAmount.mul(997);
        uint numerator = amountInputWithFee.mul(outputReserve);
        uint denominator = inputReserve.mul(1000).add(amountInputWithFee);
        return numerator / denominator;
    }

    function update(uint balance0, uint balance1) private {
        uint32 blockNumber = uint32(block.number % 2**32);
        uint32 blocksElapsed = blockNumber - blockNumberLast; // overflow is desired
        if (blocksElapsed > 0 && reserve0 != 0 && reserve1 != 0) {
            // in the following 2 lines, * never overflows, + overflow is desired
            priceCumulative0 += uint256(UQ112x112.encode(reserve0).qdiv(reserve1)) * blocksElapsed;
            priceCumulative1 += uint256(UQ112x112.encode(reserve1).qdiv(reserve0)) * blocksElapsed;
        }
        reserve0 = balance0.clamp112();
        reserve1 = balance1.clamp112();
        blockNumberLast = blockNumber;
    }

    // mint liquidity equivalent to 20% of accumulated fees
    function mintFeeLiquidity() private {
        uint invariant = Math.sqrt(uint(reserve0).mul(reserve1));
        if (invariant > invariantLast) {
            uint numerator = totalSupply.mul(invariant.sub(invariantLast));
            uint denominator = uint256(4).mul(invariant).add(invariantLast);
            uint liquidity = numerator / denominator;
            _mint(factory, liquidity); // factory is just a placeholder
            emit FeeLiquidityMinted(liquidity);
        }
    }

    function mintLiquidity(address recipient) external lock returns (uint liquidity) {
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), "UniswapV2: EXCESS_LIQUIDITY");
        uint amount0 = balance0.sub(reserve0);
        uint amount1 = balance1.sub(reserve1);

        mintFeeLiquidity();
        liquidity = totalSupply == 0 ?
            Math.sqrt(amount0.mul(amount1)) :
            Math.min(amount0.mul(totalSupply) / reserve0, amount1.mul(totalSupply) / reserve1);
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");
        _mint(recipient, liquidity);

        update(balance0, balance1);
        invariantLast = Math.sqrt(uint(reserve0).mul(reserve1));
        emit LiquidityMinted(msg.sender, recipient, amount0, amount1, reserve0, reserve1, liquidity);
    }

    function burnLiquidity(address recipient) external lock returns (uint amount0, uint amount1) {
        uint liquidity = balanceOf[address(this)];
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        require(balance0 >= reserve0 && balance0 >= reserve1, "UniswapV2: INSUFFICIENT_BALANCE");

        mintFeeLiquidity();
        amount0 = liquidity.mul(balance0) / totalSupply; // intentionally using balances not reserves
        amount1 = liquidity.mul(balance1) / totalSupply; // intentionally using balances not reserves
        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_VALUE");
        safeTransfer(token0, recipient, amount0);
        safeTransfer(token1, recipient, amount1);
        _burn(address(this), liquidity);

        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        invariantLast = Math.sqrt(uint(reserve0).mul(reserve1));
        emit LiquidityBurned(msg.sender, recipient, amount0, amount1, reserve0, reserve1, liquidity);
    }

    function swap0(address recipient) external lock returns (uint amount1) {
        uint balance0 = IERC20(token0).balanceOf(address(this));
        require(balance0 <= uint112(-1), "UniswapV2: EXCESS_BALANCE");
        uint amount0 = balance0.sub(reserve0);

        amount1 = getInputPrice(amount0, reserve0, reserve1);
        require(amount1 > 0, "UniswapV2: INSUFFICIENT_VALUE");
        safeTransfer(token1, recipient, amount1);

        update(balance0, IERC20(token1).balanceOf(address(this)));
        emit Swap(msg.sender, recipient, amount0, amount1, reserve0, reserve1, token0);
    }

    function swap1(address recipient) external lock returns (uint amount0) {
        uint balance1 = IERC20(token1).balanceOf(address(this));
        require(balance1 <= uint112(-1), "UniswapV2: EXCESS_BALANCE");
        uint amount1 = balance1.sub(reserve1);

        amount0 = getInputPrice(amount1, reserve1, reserve0);
        require(amount0 > 0, "UniswapV2: INSUFFICIENT_VALUE");
        safeTransfer(token0, recipient, amount0);

        update(IERC20(token0).balanceOf(address(this)), balance1);
        emit Swap(msg.sender, recipient, amount0, amount1, reserve0, reserve1, token1);
    }

    // almost never _needs_ to be called, it's for weird tokens and can also be helpful for oracles
    function sync() external lock {
        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }

    function sweep() external lock {
        mintFeeLiquidity();
        invariantLast = Math.sqrt(uint(reserve0).mul(reserve1));
    }
}
