pragma solidity =0.5.16;

import './interfaces/IUniswapV3Pair.sol';
import './UniswapV3ERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IUniswapV3Callee.sol';

// library TODO: sqrt() and reciprocal() methods on UQ112x112, and multiplication of two UQ112s

contract UniswapV3Pair is IUniswapV3Pair, UniswapV3ERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public token0;
    address public token1;

    uint public lpFee; // in bps

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    int16 public currentTick; // the current tick for the token0 price. when odd, current price is between ticks

    uint private unlocked = 1;

    struct LimitPool {
        uint112 quantity0; // quantity of token0 available
        uint112 quantity1; // quantity of token1 available
        uint32 cycle; // number of times the tick has been crossed entirely
                          // index is even if pool is initially selling token0, odd if is initially selling token1
    }
    
    mapping (int16 => LimitPool) limitPools; // mapping from tick indexes to limit pools
    mapping (bytes32 => uint112) limitOrders; // mapping from sha3(user, tick index, cycle) to order

    modifier lock() {
        require(unlocked == 1, 'UniswapV3: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV3: TRANSFER_FAILED');
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() public {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV3: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'UniswapV3: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV3Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'UniswapV3: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'UniswapV3: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function getTradeToRatio(uint y0, uint x0, uint224 price) internal returns uint {
        // todo: fix this
        // simplification of https://www.wolframalpha.com/input/?i=solve+%28x0+-+x0*%281-g%29*y%2F%28y0+%2B+%281-g%29*y%29%29%2F%28y0+%2B+y%29+%3D+p+for+y
        uint numerator = (price.sqrt().mul(Math.sqrt(y0)).mul(Math.sqrt(price.mul(y0).mul(lpFee).mul(lpFee).div(10000) + price.mul(4 * x0).mul(10000 - lpFee))).truncate();
        uint denominator = price.mul(10000 - lpFee).div(10000).mul(2).truncate()
        return numerator / denominator;
    }

    function swap0for1(uint amount0In, bytes calldata data) external lock {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint _currentTick = currentTick;

        uint totalAmountOut = 0;

        while (amountInLeft > 0) {
            uint224 price = getTickPrice(_currentTick);

            if (currentTick % 2 == 0) {                
                // we are in limit order mode
                LimitPool storage pool = limitPools[currentTick];

                // compute how much would need to be traded to fill the limit order
                uint maxAmountToBuy = pool.quantity1.sub(pool.quantity1.mul(lpFee).div(20000)); // half of fee is paid in token1
                uint maxAmount = price.reciprocal().mul(maxAmountToBuy).div((20000 - lpFee).mul(20000)).truncate();

                uint amountToTrade = (amountInLeft > maxAmount) ? maxAmount : amountInLeft;

                // execute the sell of amountToTrade
                uint adjustedAmountToTrade = amountToTrade.sub(amountToTrade.mul(lpFee).div(20000));
                uint adjustedAmountOut = price.mul(adjustedAmountToTrade).div();
                totalAmountOut += amountOut;
                pool.amount1 -= amountOut; // TODO: handle rounding errors around 0
                pool.amount0 += amountToTrade;

                amountInLeft = amountInLeft - amountToTrade;

                if (amountInLeft == 0) {
                    // new cycle
                    pool = LimitPool(0, 0, pool.cycle + 1);
                }
            } else {
                // we are in Uniswap mode
                // compute how much would need to be traded to get to the next tick down
                uint maxAmount = getTradeToRatio(_reserve0, _reserve1, 30, lowerTick);
            
                uint amountToTrade = (amountInLeft > maxAmount) ? maxAmount : amountInLeft;

                // execute the sell of amountToTrade
                uint adjustedAmountToTrade = amountToTrade.mul(10000 - lpFee).div(10000);
                uint amountOut = adjustedAmountToTrade.mul(_reserve1).div(_reserve0 + adjustedAmountToTrade);
                _reserve0 -= amountOut;
                _reserve1 += amountToTrade;

                amountInLeft = amountInLeft - amountToTrade;
            }
            if (amountInLeft == 0) {
                currentTick -= 1;
            }
        }
        currentTick = _currentTick;
        if (data.length > 0) IUniswapV3Callee(to).uniswapV3Call(msg.sender, amount0Out, amount1Out, data);
        // TODO: make safe or do v2 style
        require(token0.transferFrom(msg.sender, amount0In), "UniswapV3: TRANSFERFROM_FAILED");
        
        // TODO: emit event, update oracle, etc
    }

    // // this low-level function should be called from a contract which performs important safety checks
    // function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
    //     require(amount0Out > 0 || amount1Out > 0, 'UniswapV3: INSUFFICIENT_OUTPUT_AMOUNT');
    //     (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
    //     require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV3: INSUFFICIENT_LIQUIDITY');

    //     uint balance0;
    //     uint balance1;
    //     { // scope for _token{0,1}, avoids stack too deep errors
    //     address _token0 = token0;
    //     address _token1 = token1;
    //     require(to != _token0 && to != _token1, 'UniswapV3: INVALID_TO');
    //     if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
    //     if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
    //     if (data.length > 0) IUniswapV3Callee(to).uniswapV3Call(msg.sender, amount0Out, amount1Out, data);
    //     balance0 = IERC20(_token0).balanceOf(address(this));
    //     balance1 = IERC20(_token1).balanceOf(address(this));
    //     }
    //     uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
    //     uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
    //     require(amount0In > 0 || amount1In > 0, 'UniswapV3: INSUFFICIENT_INPUT_AMOUNT');
    //     { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
    //     uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
    //     uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
    //     require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UniswapV3: K');
    //     }

    //     _update(balance0, balance1, _reserve0, _reserve1);
    //     emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    // }


    function getTickPrice(int256 index) returns uint {
        // returns a UQ112x112 representing the price of token0 in terms of token1, at the tick with that index
        // odd tick indices (representing bands between ticks) 

        index = index / uint(2);

        if (index == 0) {
            return UQ112x112.encode(1);
        }

        // compute 1.01^abs(index)
        // TODO: improve and fix this math
        // adapted from https://ethereum.stackexchange.com/questions/10425/is-there-any-efficient-way-to-compute-the-exponentiation-of-a-fraction-and-an-in
        uint224 price = 0;
        uint N = 1;
        uint B = 1;
        uint q = 100;
        uint precision = 50;
        for (uint i = 0; i < precision; ++i){
            price += k * N / B / q;
            N  = N * (n-i);
            B  = B * (i+1);
            q = q * 100;
        }

        if (index < 0) {
            return price.reciprocal();
        }
        return price;
    }

    // merge these two into one function? kinda unsafe
    function placeOrder0(int16 tick, uint112 amount) external lock {
        // place a limit sell order for token0
        require(tick > currentTick, "UniswapV3: LIMIT_ORDER_PRICE_TOO_LOW");
        LimitPool storage limitPool = limitPools[tick];
        limitPool.quantity0 += amount;
        limitOrders[sha3(msg.sender, tick, limitPool.cycle)] += amount;
        
        // TODO: make safe or do v2 style
        require(token0.transferFrom(msg.sender, amount), "UniswapV3: TRANSFERFROM_FAILED");
    }
    
    function placeOrder1(int16 tick, uint112 amount) external lock {
        // place a limit sell order for token0
        require(tick > currentTick, "UniswapV3: LIMIT_ORDER_PRICE_TOO_HIGH");
        LimitPool storage limitPool = limitPools[tick];
        limitPool.quantity1 += amount;
        limitOrders[sha3(msg.sender, tick, limitPool.cycle)] += amount;
        
        // TODO: make safe or do v2 style
        require(token1.transferFrom(msg.sender, amount), "UniswapV3: TRANSFERFROM_FAILED");
    }

    function cancel(int16 tick, uint cycle) external lock {
        // cancel a limit order that has not yet filled
        LimitPool limitPool = limitPools[tick];
        require(limitPool.cycle == cycle, "UniswapV3: ORDER_FILLED");
        require(tick != currentTick, "UniswapV3: ORDER_PENDING"); // TODO: allow someone to withdraw pro rata from a partial order
        uint112 storage amount = limitOrders[sha3(msg.sender, tick, cycle)];
        amount = 0;
        if (cycle % 2 == 0) {
            _safeTransfer(token0, recipient, amount);
        } else {
            _safeTransfer(token1, recipient, amount);
        }
    }

    function complete(int16 tick, uint cycle, address recipient) {
        // withdraw a completed limit order
        LimitPool limitPool = limitPools[tick];
        require(limitPool.cycle > cycle, "UniswapV3: ORDER_INCOMPLETE");
        uint112 amount = limitOrders[sha3(msg.sender, tick, cycle)];
        uint224 price = getTickPrice(currentTick);
        if (cycle % 2 == 0) {
            _safeTransfer(token1, recipient, UQ112x112.encode(amount).uqmul(price));
        } else {
            _safeTransfer(token0, recipient, UQ112x112.encode(amount).uqdiv(price));
        }
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
