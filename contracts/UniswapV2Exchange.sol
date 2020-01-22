pragma solidity =0.5.16;

import "./interfaces/IUniswapV2Exchange.sol";
import "./UniswapV2ERC20.sol";
import "./libraries/Math.sol";
import "./libraries/UQ112x112.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract UniswapV2Exchange is IUniswapV2Exchange, UniswapV2ERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    bytes4 constant public selector = bytes4(keccak256(bytes("transfer(address,uint256)")));
    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;        // single storage slot, (jointly) access via getReserves
    uint112 private reserve1;        // single storage slot, (jointly) access via getReserves
    uint32  private blockNumberLast; // single storage slot, (jointly) access via getReserves
    
    uint    public  price0CumulativeLast;
    uint    public  price1CumulativeLast;
    uint    public invariantLast;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address indexed sender, address indexed tokenIn, uint amountIn, uint amountOut, address indexed to);
    event Sync(uint112 reserve0, uint112 reserve1);

    bool private unlocked = true;
    modifier lock() {
        require(unlocked, "UniswapV2: LOCKED");
        unlocked = false;
        _;
        unlocked = true;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(selector, to, value));
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

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockNumberLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockNumberLast = blockNumberLast;
    }

    // update reserves and, on the first time this function is called per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), "UniswapV2: BALANCE_OVERFLOW");
        uint32 blockNumber = uint32(block.number % 2**32);
        uint32 blocksElapsed = blockNumber - blockNumberLast; // overflow is desired
        if (blocksElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * blocksElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * blocksElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockNumberLast = blockNumber;
        emit Sync(reserve0, reserve1);
    }

    // mint liquidity equivalent to 20% of newly accumulated fees
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        if (feeOn) {
            uint _invariantLast = invariantLast; // gas savings
            if (_invariantLast != 0) {
                uint invariant = Math.sqrt(uint(_reserve0).mul(_reserve1));
                if (invariant > _invariantLast) {
                    uint numerator = totalSupply.mul(invariant.sub(_invariantLast));
                    uint denominator = invariant.mul(4).add(_invariantLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        }
    }

    // mint liquidity
    function mint(address to) external lock returns (uint liquidity) {
        uint    _totalSupply = totalSupply; // gas savings
        uint112 _reserve0 = reserve0;       // gas savings
        uint112 _reserve1 = reserve1;       // gas savings
        uint    balance0 = IERC20(token0).balanceOf(address(this));
        uint    balance1 = IERC20(token1).balanceOf(address(this));
        uint    amount0 = balance0.sub(_reserve0);
        uint    amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        liquidity = _totalSupply == 0 ?
            Math.sqrt(amount0.mul(amount1)) :
            Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        require(liquidity > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) invariantLast = Math.sqrt(uint(reserve0).mul(reserve1));
        emit Mint(msg.sender, amount0, amount1);
    }

    // burn liquidity
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        uint    _totalSupply = totalSupply; // gas savings
        uint112 _reserve0 = reserve0;       // gas savings
        uint112 _reserve1 = reserve1;       // gas savings
        address _token0 = token0;           // gas savings
        address _token1 = token1;           // gas savings
        uint    balance0 = IERC20(_token0).balanceOf(address(this));
        uint    balance1 = IERC20(_token1).balanceOf(address(this));
        uint    liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        amount0 = liquidity.mul(balance0) / _totalSupply; // use balances instead of reserves to address edge case
        amount1 = liquidity.mul(balance1) / _totalSupply; // use balances instead of reserves to address edge case
        require(amount0 > 0 && amount1 > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED");
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) invariantLast = Math.sqrt(uint(reserve0).mul(reserve1));
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // swap tokens
    function swap(address tokenIn, uint amountOut, address to) external lock {
        uint112 _reserve0 = reserve0; // gas savings
        uint112 _reserve1 = reserve1; // gas savings
        address _token0 = token0;     // gas savings
        address _token1 = token1;     // gas savings
        uint balance0; uint balance1; uint amountIn;

        if (tokenIn == _token0) {
            require(0 < amountOut && amountOut < _reserve1, "UniswapV2: INVALID_OUTPUT_AMOUNT");
            balance0 = IERC20(_token0).balanceOf(address(this));
            amountIn = balance0.sub(_reserve0);
            require(amountIn > 0, "UniswapV2: INSUFFICIENT_INPUT_AMOUNT");
            require(amountIn.mul(_reserve1 - amountOut).mul(997) >= amountOut.mul(_reserve0).mul(1000), "UniswapV2: K");
            _safeTransfer(_token1, to, amountOut);
            balance1 = IERC20(_token1).balanceOf(address(this));
        } else {
            require(tokenIn == _token1, "UniswapV2: INVALID_INPUT_TOKEN");
            require(0 < amountOut && amountOut < _reserve0, "UniswapV2: INVALID_OUTPUT_AMOUNT");
            balance1 = IERC20(_token1).balanceOf(address(this));
            amountIn = balance1.sub(_reserve1);
            require(amountIn > 0, "UniswapV2: INSUFFICIENT_INPUT_AMOUNT");
            require(amountIn.mul(_reserve0 - amountOut).mul(997) >= amountOut.mul(_reserve1).mul(1000), "UniswapV2: K");
            _safeTransfer(_token0, to, amountOut);
            balance0 = IERC20(_token0).balanceOf(address(this));
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, tokenIn, amountIn, amountOut, to);
    }

    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    // force reserves to match balances
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}
