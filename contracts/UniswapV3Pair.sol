pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '@uniswap/lib/contracts/libraries/Babylonian.sol';

import './interfaces/IUniswapV3Pair.sol';
import './UniswapV3ERC20.sol';
import './libraries/Math.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapV3Factory.sol';
import './interfaces/IUniswapV3Callee.sol';
import './libraries/FixedPointExtra.sol';

// library TODO: multiply two UQ112x112s, add two UQ112x112s

contract UniswapV3Pair is UniswapV3ERC20, IUniswapV3Pair {
    using SafeMath for uint;
    using SafeMath for uint112;
    using FixedPoint for FixedPoint.uq112x112;
    using FixedPointExtra for FixedPoint.uq112x112;
    using FixedPoint for FixedPoint.uq144x112;

    uint public constant override MINIMUM_LIQUIDITY = 10**3;

    address public immutable override factory;
    address public immutable override token0;
    address public immutable override token1;

    uint112 public lpFee; // in bps

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint public override price0CumulativeLast;
    uint public override price1CumulativeLast;
    uint public override kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    int16 public currentTick; // the current tick for the token0 price. when odd, current price is between ticks

    uint private unlocked = 1;

    struct LimitPool {
        uint112 quantity0; // quantity of token0 available
        uint112 quantity1; // quantity of token1 available
        uint32 cycle; // number of times the tick has been crossed entirely
                          // index is even if pool is initially selling token0, odd if is initially selling token1
    }

    mapping (int16 => LimitPool) limitPools; // mapping from tick indexes to limit pools
    mapping (bytes32 => uint112) limitOrders; // mapping from keccak256(user, tick index, cycle) to order // TODO: how do I do this less awkwardly

    modifier lock() {
        require(unlocked == 1, 'UniswapV3: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public override view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    constructor(address token0_, address token1_) public {
        factory = msg.sender;
        token0 = token0_;
        token1 = token1_;
    }

    // called once immediately after construction by the factory
    function initialize(string calldata name_, string calldata symbol_) external {
        require(msg.sender == factory, 'UniswapV3Pair: FACTORY');
        name = name_;
        symbol = symbol_;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'UniswapV3: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // + overflow is desired
            price0CumulativeLast += FixedPoint.encode(_reserve1).div(_reserve0).mul(timeElapsed).decode144();
            price1CumulativeLast += FixedPoint.encode(_reserve0).div(_reserve1).mul(timeElapsed).decode144();
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
                uint rootK = Babylonian.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Babylonian.sqrt(_kLast);
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
    function mint(address to) external override lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Babylonian.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
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
    function burn(address to) external override lock returns (uint amount0, uint amount1) {
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
        TransferHelper.safeTransfer(_token0, to, amount0);
        TransferHelper.safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function getTradeToRatio(uint112 y0, uint112 x0, FixedPoint.uq112x112 memory price) internal view returns (uint112) {
        // todo: clean up this monstrosity, which won't even compile because the stack is too deep
        // simplification of https://www.wolframalpha.com/input/?i=solve+%28x0+-+x0*%281-g%29*y%2F%28y0+%2B+%281-g%29*y%29%29%2F%28y0+%2B+y%29+%3D+p+for+y
        // uint112 numerator = price.sqrt().mul112(uint112(Babylonian.sqrt(y0))).mul112(uint112(Babylonian.sqrt(price.mul112(y0).mul112(lpFee).mul112(lpFee).div(10000).add(price.mul112(4 * x0).mul112(10000 - lpFee)).decode()))).decode();
        // uint112 denominator = price.mul112(10000 - lpFee).div(10000).mul112(2).decode();
        return uint112(1);
    }

    // TODO: implement swap1for0, or integrate it into this
    // one difference is that swap1for0 will need to initialize cycle to 1 if it starts at 0
    function swap0for1(uint amount0In, address to, bytes calldata data) external lock {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        int16 _currentTick = currentTick;

        uint112 totalAmountOut = 0;

        uint112 amountInLeft = uint112(amount0In);

        while (amountInLeft > 0) {
            FixedPoint.uq112x112 memory price = getTickPrice(_currentTick);

            if (currentTick % 2 == 0) {
                // we are in limit order mode
                LimitPool memory pool = limitPools[currentTick];

                // compute how much would need to be traded to fill the limit order
                uint112 maxAmountToBuy = pool.quantity1 - (pool.quantity1 * lpFee / 20000); // half of fee is paid in token1
                uint112 maxAmount = price.reciprocal().mul112(maxAmountToBuy).div(uint112((20000 - lpFee) * (20000))).decode();

                uint112 amountToTrade = (amountInLeft > maxAmount) ? maxAmount : amountInLeft;

                // execute the sell of amountToTrade
                uint112 adjustedAmountToTrade = uint112(amountToTrade - ((amountToTrade * lpFee) / 20000));
                uint112 adjustedAmountOut = uint112(price.mul112(adjustedAmountToTrade - adjustedAmountToTrade * lpFee / 20000).decode());
                totalAmountOut += adjustedAmountOut;
                pool.quantity1 -= adjustedAmountOut; // TODO: handle rounding errors around 0
                pool.quantity0 += amountToTrade;

                amountInLeft = amountInLeft - amountToTrade;

                if (amountInLeft == 0) {
                    // new cycle
                    limitPools[currentTick] = LimitPool(0, 0, pool.cycle + 1);
                } else {
                    limitPools[currentTick] = pool;
                }
            } else {
                // we are in Uniswap mode
                // compute how much would need to be traded to get to the next tick down
                uint112 maxAmount = getTradeToRatio(_reserve0, _reserve1, price);

                uint112 amountToTrade = (amountInLeft > maxAmount) ? maxAmount : amountInLeft;

                // execute the sell of amountToTrade
                uint112 adjustedAmountToTrade = amountToTrade * (10000 - lpFee) / 10000;
                uint112 amountOut = (adjustedAmountToTrade * _reserve1) / (_reserve0 + adjustedAmountToTrade);
                _reserve0 -= amountOut;
                _reserve1 += amountToTrade;

                amountInLeft = amountInLeft - amountToTrade;
            }
            if (amountInLeft == 0) {
                currentTick -= 1;
            }
        }
        currentTick = _currentTick;
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        if (data.length > 0) IUniswapV3Callee(to).uniswapV3Call(msg.sender, 0, totalAmountOut, data);
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0In);

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
    //     if (amount0Out > 0) TransferHelper.safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
    //     if (amount1Out > 0) TransferHelper.safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
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


    function getTickPrice(int16 index) public pure returns (FixedPoint.uq112x112 memory) {
        // returns a UQ112x112 representing the price of token0 in terms of token1, at the tick with that index
        // odd tick indices (representing bands between ticks)

        index = index / int16(2);

        if (index == 0) {
            return FixedPoint.encode(1);
        }

        // compute 1.01^abs(index)
        // TODO: improve and fix this math
        // adapted from https://ethereum.stackexchange.com/questions/10425/is-there-any-efficient-way-to-compute-the-exponentiation-of-a-fraction-and-an-in
        FixedPoint.uq112x112 memory price = FixedPoint.encode(0);
        FixedPoint.uq112x112 memory N = FixedPoint.encode(1);
        uint112 B = 1;
        uint112 q = 100;
        uint precision = 50;
        for (uint i = 0; i < precision; ++i){
            price.add(N.div(B).div(q));
            N  = N.mul112(uint112(index - int16(i)));
            B = B * uint112(i+1);
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
        if (limitPool.cycle == 0) {
            limitPool.cycle = 1;
        }
        limitPool.quantity0 += amount;
        limitOrders[keccak256(abi.encodePacked(msg.sender, tick, limitPool.cycle))] += amount;

        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount);
    }

    function placeOrder1(int16 tick, uint112 amount) external lock {
        // place a limit sell order for token0
        require(tick > currentTick, "UniswapV3: LIMIT_ORDER_PRICE_TOO_HIGH");
        LimitPool storage limitPool = limitPools[tick];
        limitPool.quantity1 += amount;
        limitOrders[keccak256(abi.encodePacked(msg.sender, tick, limitPool.cycle))] += amount;

        TransferHelper.safeTransferFrom(token1, msg.sender, address(this), amount);
    }

    function cancel(int16 tick, uint cycle, address to) external lock {
        // cancel a limit order that has not yet filled
        LimitPool storage limitPool = limitPools[tick];
        require(limitPool.cycle == cycle, "UniswapV3: ORDER_FILLED");
        require(tick != currentTick, "UniswapV3: ORDER_PENDING"); // TODO: allow someone to withdraw pro rata from a partial order
        bytes32 key = keccak256(abi.encodePacked(msg.sender, tick, cycle));
        uint112 amount = limitOrders[key];
        limitOrders[key] = 0;
        if (cycle % 2 == 0) {
            limitPool.quantity0 -= amount;
            TransferHelper.safeTransfer(token0, to, amount);
        } else {
            limitPool.quantity1 -= amount;
            TransferHelper.safeTransfer(token1, to, amount);
        }
    }

    function complete(int16 tick, uint cycle, address to) external lock {
        // withdraw a completed limit order
        require(limitPools[tick].cycle > cycle, "UniswapV3: ORDER_INCOMPLETE");
        bytes32 key = keccak256(abi.encodePacked(msg.sender, tick, cycle));
        uint112 amount = limitOrders[key];
        limitOrders[key] = 0;
        FixedPoint.uq112x112 memory price = getTickPrice(currentTick);
        if (cycle % 2 == 0) {
            TransferHelper.safeTransfer(token1, to, price.mul112(amount).decode());
        } else {
            TransferHelper.safeTransfer(token0, to, price.reciprocal().mul112(amount).decode());
        }
    }

    // // force balances to match reserves
    // function skim(address to) external lock {
    //     address _token0 = token0; // gas savings
    //     address _token1 = token1; // gas savings
    //     TransferHelper.safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
    //     TransferHelper.safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    // }

    // // force reserves to match balances
    // function sync() external lock {
    //     _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    // }
}
