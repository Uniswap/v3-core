pragma solidity 0.5.15;

import "./interfaces/IUniswapV2.sol";
import "./ERC20.sol";
import "./libraries/UQ112x112.sol";
import "./libraries/Math.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract UniswapV2 is IUniswapV2, ERC20("Uniswap V2", "UNI-V2", 18, 0) {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    address public factory;
    address public token0;
    address public token1;

    uint112 public reserve0;
    uint112 public reserve1;
    uint32  public blockNumberLast;
    uint    public price0CumulativeLast;
    uint    public price1CumulativeLast;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1);
    event Swap(address indexed sender, address indexed tokenIn, uint amountIn, uint amountOut);
    event Sync(uint112 reserve0, uint112 reserve1);

    bool private unlocked = true;
    modifier lock() {
        require(unlocked, "UniswapV2: LOCKED");
        unlocked = false;
        _;
        unlocked = true;
    }

    function _safeTransfer(address token, address to, uint value) private {
        // solium-disable-next-line security/no-low-level-calls
        (bool success, bytes memory data) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "UniswapV2: TRANSFER_FAILED");
    }

    constructor() public {
        factory = msg.sender;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory && token0 == address(0) && token1 == address(0), "UniswapV2: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    // update reserves + block number and, if necessary, increment price accumulators
    function _update(uint balance0, uint balance1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), "UniswapV2: BALANCE_OVERFLOW");
        uint32 blockNumber = uint32(block.number % 2**32);
        uint32 blocksElapsed = blockNumber - blockNumberLast; // overflow is desired
        if (reserve0 != 0 && reserve1 != 0 && blocksElapsed > 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(reserve0).qdiv(reserve1)) * blocksElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(reserve1).qdiv(reserve0)) * blocksElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockNumberLast = blockNumber;
        emit Sync(reserve0, reserve1);
    }

    function mint() external lock returns (uint liquidity) {
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(reserve0);
        uint amount1 = balance1.sub(reserve1);

        liquidity = totalSupply == 0 ?
            Math.sqrt(amount0.mul(amount1)) :
            Math.min(amount0.mul(totalSupply) / reserve0, amount1.mul(totalSupply) / reserve1);
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(msg.sender, liquidity);

        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn() external lock returns (uint amount0, uint amount1) {
        uint liquidity = balanceOf[address(this)];

        // there's a funny case here where if a token deflates uniswap's balance, we give too many tokens...
        amount0 = liquidity.mul(reserve0) / totalSupply;
        amount1 = liquidity.mul(reserve1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED");
        _safeTransfer(token0, msg.sender, amount0);
        _safeTransfer(token1, msg.sender, amount1);
        _burn(address(this), liquidity);

        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
        emit Burn(msg.sender, amount0, amount1);
    }

    function swap(address tokenIn, uint amountOut) external lock {
        uint balance0; uint balance1; uint amountIn; uint fee;
        address feeRecipient = IUniswapV2Factory(factory).feeRecipient();

        if (tokenIn == token0) {
            require(0 < amountOut && amountOut < reserve1, "UniswapV2: INVALID_OUTPUT_AMOUNT");
            balance0 = IERC20(token0).balanceOf(address(this));
            amountIn = balance0.sub(reserve0);
            require(amountIn > 0, "UniswapV2: INSUFFICIENT_INPUT_AMOUNT");
            fee = feeRecipient == address(0) ? 0 : uint(amountIn).mul(3) / 5000;
            if (fee > 0) {
                require(
                    amountIn.sub(fee).mul(reserve1 - amountOut).mul(9976) >= amountOut.mul(reserve0).mul(10000),
                    "UniswapV2: K_VIOLATED"
                );
                _safeTransfer(token0, feeRecipient, fee);
                balance0 = IERC20(token0).balanceOf(address(this)); // re-fetch balance after the transfer
            } else {
                require(
                    amountIn.mul(reserve1 - amountOut).mul(997) >= amountOut.mul(reserve0).mul(1000),
                    "UniswapV2: K_VIOLATED"
                );
            }
            _safeTransfer(token1, msg.sender, amountOut);
            balance1 = IERC20(token1).balanceOf(address(this));
        } else {
            require(tokenIn == token1, "UniswapV2: INVALID_INPUT_TOKEN");
            require(0 < amountOut && amountOut < reserve0, "UniswapV2: INVALID_OUTPUT_AMOUNT");
            balance1 = IERC20(token1).balanceOf(address(this));
            amountIn = balance1.sub(reserve1);
            require(amountIn > 0, "UniswapV2: INSUFFICIENT_INPUT_AMOUNT");
            fee = feeRecipient == address(0) ? 0 : uint(amountIn).mul(3) / 5000;
            if (fee > 0) {
                require(
                    amountIn.sub(fee).mul(reserve0 - amountOut).mul(9976) >= amountOut.mul(reserve1).mul(10000),
                    "UniswapV2: K_VIOLATED"
                );
                _safeTransfer(token1, feeRecipient, fee);
                balance1 = IERC20(token1).balanceOf(address(this)); // re-fetch balance after the transfer
            } else {
                require(
                    amountIn.mul(reserve0 - amountOut).mul(997) >= amountOut.mul(reserve1).mul(1000),
                    "UniswapV2: K_VIOLATED"
                );
            }
            _safeTransfer(token0, msg.sender, amountOut);
            balance0 = IERC20(token0).balanceOf(address(this));
        }

        _update(balance0, balance1);
        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    // force balances to match reserves
    function skim() external lock {
        _safeTransfer(token0, msg.sender, IERC20(token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(token1, msg.sender, IERC20(token1).balanceOf(address(this)).sub(reserve1));
    }

    // force reserves to match balances
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)));
    }
}
