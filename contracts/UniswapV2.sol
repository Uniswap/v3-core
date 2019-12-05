pragma solidity 0.5.12;

import "./interfaces/IUniswapV2.sol";

import "./libraries/Math.sol";
import "./libraries/UQ128x128.sol";

import "./token/ERC20.sol";
import "./token/SafeTransfer.sol";

contract UniswapV2 is IUniswapV2, ERC20("Uniswap V2", "UNI-V2", 18, 0), SafeTransfer {
    using SafeMath for uint;
    using UQ128x128 for uint;

    address public factory;
    address public token0; address public token1;

    uint128 public reserve0; uint128 public reserve1;
    uint   public priceCumulative0;         uint public   priceCumulative1;
    uint64 public priceCumulative0Overflow; uint64 public priceCumulative1Overflow; uint64 public blockNumber;

    bool private notEntered = true;
    modifier lock() {
        require(notEntered, "UniswapV2: LOCKED");
        notEntered = false;
        _;
        notEntered = true;
    }

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


    constructor() public {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(token0 == address(0) && token1 == address(0), 'UniswapV2: ALREADY_INITIALIZED');
        (token0, token1) = (_token0, _token1);
    }

    // uniswap-v1 naming
    function getInputPrice(uint inputAmount, uint inputReserve, uint outputReserve) public pure returns (uint) {
        require(inputReserve > 0 && outputReserve > 0, "UniswapV2: INVALID_VALUE");
        uint amountInputWithFee = inputAmount.mul(997);
        uint numerator = amountInputWithFee.mul(outputReserve);
        uint denominator = inputReserve.mul(1000).add(amountInputWithFee);
        return numerator / denominator;
    }

    function update(uint balance0, uint balance1) private {
        if (block.number > blockNumber) {
            if (reserve0 != 0 && reserve1 != 0) {
                uint64 blocksElapsed = uint64(block.number) - blockNumber; // doesn't overflow until >the end of time
                (uint p0, uint64 po0) = Math.mul512(UQ128x128.encode(reserve0).qdiv(reserve1), blocksElapsed);
                (uint p1, uint64 po1) = Math.mul512(UQ128x128.encode(reserve1).qdiv(reserve0), blocksElapsed);
                uint64 pc0o; uint64 pc1o;
                (priceCumulative0, pc0o) = Math.add512(priceCumulative0, priceCumulative0Overflow, p0, po0);
                (priceCumulative1, pc1o) = Math.add512(priceCumulative1, priceCumulative1Overflow, p1, po1);
                (priceCumulative0Overflow, priceCumulative1Overflow) = (pc0o, pc1o);
            }
            blockNumber = uint64(block.number); // doesn't overflow until >the end of time
        }
        (reserve0, reserve1) = (balance0.clamp128(), balance1.clamp128()); // update reserves
    }

    function mintLiquidity(address recipient) external lock returns (uint liquidity) {
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(reserve0);
        uint amount1 = balance1.sub(reserve1);

        liquidity = totalSupply == 0 ?
            Math.sqrt(amount0.mul(amount1)) :
            Math.min(amount0.mul(totalSupply) / reserve0, amount1.mul(totalSupply) / reserve1);
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");
        mint(recipient, liquidity);

        update(balance0, balance1);
        emit LiquidityMinted(msg.sender, recipient, amount0, amount1, reserve0, reserve1, liquidity);
    }

    function burnLiquidity(address recipient) external lock returns (uint amount0, uint amount1) {
        uint liquidity = balanceOf[address(this)];
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");

        amount0 = liquidity.mul(reserve0) / totalSupply;
        amount1 = liquidity.mul(reserve1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_VALUE");
        safeTransfer(token0, recipient, amount0);
        safeTransfer(token1, recipient, amount1);

        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        emit LiquidityBurned(msg.sender, recipient, amount0, amount1, reserve0, reserve1, liquidity);
    }

    function swap0(address recipient) external lock returns (uint amount1) {
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint amount0 = balance0.sub(reserve0); // this can fail for weird tokens, hence sync

        require(amount0 > 0, "UniswapV2: INSUFFICIENT_VALUE_INPUT");
        amount1 = getInputPrice(amount0, reserve0, reserve1);
        require(amount1 > 0, "UniswapV2: INSUFFICIENT_VALUE_OUTPUT");
        safeTransfer(token1, recipient, amount1);

        update(balance0, IERC20(token1).balanceOf(address(this)));
        emit Swap(msg.sender, recipient, amount0, amount1, reserve0, reserve1, token0);
    }

    function swap1(address recipient) external lock returns (uint amount0) {
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount1 = balance1.sub(reserve1); // this can fail for weird tokens, hence sync

        require(amount1 > 0, "UniswapV2: INSUFFICIENT_VALUE_INPUT");
        amount0 = getInputPrice(amount1, reserve1, reserve0);
        require(amount0 > 0, "UniswapV2: INSUFFICIENT_VALUE_OUTPUT");
        safeTransfer(token0, recipient, amount0);

        update(IERC20(token0).balanceOf(address(this)), balance1);
        emit Swap(msg.sender, recipient, amount0, amount1, reserve0, reserve1, token1);
    }

    // this function almost certainly never needs to be called, it's for weird token
    function sync() external lock {
        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }

    // DONT CALL THIS FUNCTION UNLESS token0 IS PERMANENTLY BROKEN
    function unsafeRageQuit0(address recipient) external lock returns (uint amount1) {
        uint liquidity = balanceOf[address(this)];
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");

        uint amount0 = liquidity.mul(reserve0) / totalSupply;
        amount1 = liquidity.mul(reserve1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_VALUE");
        safeTransfer(token1, recipient, amount1);

        update(IERC20(token0).balanceOf(address(this)).sub(amount0), IERC20(token1).balanceOf(address(this)));
        emit LiquidityBurned(msg.sender, recipient, 0, amount1, reserve0, reserve1, liquidity);
    }

    // DONT CALL THIS FUNCTION UNLESS token1 IS PERMANENTLY BROKEN
    function unsafeRageQuit1(address recipient) external lock returns (uint amount0) {
        uint liquidity = balanceOf[address(this)];
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_VALUE");

        amount0 = liquidity.mul(reserve0) / totalSupply;
        uint amount1 = liquidity.mul(reserve1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_VALUE");
        safeTransfer(token0, recipient, amount0);

        update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)).sub(amount1));
        emit LiquidityBurned(msg.sender, recipient, amount0, 0, reserve0, reserve1, liquidity);
    }
}
