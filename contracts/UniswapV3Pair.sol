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

    uint112 private virtualSupply;  // current virtual supply;
    uint64 private timeInitialized; // timestamp when pool was initialized

    uint16 public currentTick; // the current tick for the token0 price (rounded down)

    uint private unlocked = 1;
    
    struct TickInfo {
        uint32 secondsGrowthOutside;         // measures number of seconds spent while pool was on other side of this tick (from the current price)
        FixedPoint.uq112x112 kGrowthOutside; // measures growth due to fees while pool was on the other side of this tick (from the current price)
    }

    struct Delta {
        uint112 sharesOut;                   // number of shares that should be kicked out when this tick is crossed 
        uint112 tokensIn;                    // number of tokens that should be kicked in when this tick is crossed
    }
    
    mapping (uint16 => TickInfo) tickInfos;  // mapping from tick indexes to information about that tick
    mapping (uint16 => Delta) deltas;        // mapping from tick indexes to amount of token0 kicked in or out when tick is crossed

    struct UserBounds {
        uint16 lowerTick;                   // tick for the minimum token0 price, at which their liquidity is kicked out. 0 if no lower limit
        uint16 upperTick;                   // tick for the maximum token0 price, at which their liquidity is kicked out. 0 if no lower limit
        uint224 growthOutsideStart;         // product of the starting growth level for the upper and lower bounds, last time this was updated
    }

    mapping (address => UserBounds) userBounds;

    struct UserBalances {
        uint112 token0owed;
        uint112 token1owed;
        uint112 liquidity; // virtual liquidity shares when within the range
    }

    mapping (address => UserBalances) userBalances;

    modifier lock() {
        require(unlocked == 1, 'UniswapV3: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // returns sqrt(x*y)/shares
    function getInvariant() public view returns (FixedPoint.uq112x112 memory k) {
        uint112 rootXY = uint112(Math.sqrt(uint256(reserve0) * uint256(reserve1)));
        return FixedPoint.encode(rootXY).div(virtualSupply);
    }

    function getGrowthAbove(uint16 tickIndex, uint16 _currentTick, FixedPoint.uq112x112 _k) public view returns (FixedPoint.uq112x112 memory) {
        kGrowthOutside = tickInfos[tickIndex].kGrowthOutside;
        if (_currentTick >= tickIndex) {
            // this range is currently active
            return _k.uqdiv112(kGrowthOutside);
        } else {
            // this range is currently inactive
            return kGrowthOutside;
        }
    }

    function getGrowthBelow(uint16 tickIndex, uint16 _currentTick, FixedPoint.uq112x112 _k) public view returns (FixedPoint.uq112x112 memory) {
        kGrowthOutside = tickInfos[tickIndex].kGrowthOutside;
        if (_currentTick < tickIndex) {
            // this range is currently active
            return _k.uqdiv112(kGrowthOutside);
        } else {
            // this range is currently inactive
            return kGrowthOutside;
        }
    }

    function getGrowthOutside(uint16 _lowerTick, uint16 _upperTick) public view returns (FixedPoint.uq112x112 memory growth) {
        FixedPoint.uq112x112 _k = getInvariant();
        uint16 _currentTick = currentTick;
        FixedPoint.uq112x112 growthAbove = getGrowthAbove(_upperTick, _currentTick, _k);
        FixedPoint.uq112x112 growthBelow = getGrowthBelow(_lowerTick, _currentTick, _k);
        return growthAbove.uqmul112(growthBelow);
    }

    function getReserves() public override view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    // get number of virtual liquidity tokens that a user owns, adjusted to cancel out fee growth that occurred outside of their liquidity bounds
    function adjustedVirtualBalanceOf(address user) public override view returns (uint112) {
        UserBounds memory userBounds = userBounds[user];
        FixedPoint.uq112x112 growthOutside = getGrowthOutside(userBounds.lowerTick, userBounds.upperTick);
        FixedPoint.uq112x112 adjustmentFactor = growthOutsideStart.uqdiv112(userBounds.growthOutside);
        return adjustmentFactor.mul112(virtualBalance);
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
    function _update(uint112 _reserve0, uint112 _reserve1) private {
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // + overflow is desired
            price0CumulativeLast += FixedPoint.encode(_reserve1).div(_reserve0).mul(timeElapsed).decode144();
            price1CumulativeLast += FixedPoint.encode(_reserve0).div(_reserve1).mul(timeElapsed).decode144();
        }
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        blockTimestampLast = blockTimestamp;
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
    function mint(address to, uint amount0, uint amount1) external override lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
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

        _reserve0 += amount0;
        _reserve1 += amount1;
        _update(_reserve0, _reserve1);
        if (feeOn) kLast = uint(_reserve0).mul(_reserve1);
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to, uint liquidity) external override lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(uint(reserve0)) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(uint(reserve1)) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'UniswapV3: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(msg.sender, liquidity);
        TransferHelper.safeTransfer(_token0, to, amount0);
        TransferHelper.safeTransfer(_token1, to, amount1);
        _reserve0 -= amount0;
        _reserve1 -= amount1;
        _update(_reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // donate to other liquidity providers by burning liquidity tokens without receiving tokens in return
    // TODO: figure out interaction with protocol fee
    function give(uint liquidity) {
        _burn(msg.sender, liquidity);
        emit Give(msg.sender, liquidity);
    }

    function getTradeToRatio(uint112 y0, uint112 x0, FixedPoint.uq112x112 memory price) internal view returns (uint112) {
        // todo: clean up this monstrosity, which won't even compile because the stack is too deep
        // simplification of https://www.wolframalpha.com/input/?i=solve+%28x0+-+x0*%281-g%29*y%2F%28y0+%2B+%281-g%29*y%29%29%2F%28y0+%2B+y%29+%3D+p+for+y
        // uint112 numerator = price.sqrt().mul112(uint112(Babylonian.sqrt(y0))).mul112(uint112(Babylonian.sqrt(price.mul112(y0).mul112(lpFee).mul112(lpFee).div(10000).add(price.mul112(4 * x0).mul112(10000 - lpFee)).decode()))).decode();
        // uint112 denominator = price.mul112(10000 - lpFee).div(10000).mul112(2).decode();
        return uint112(1);
    }

    // TODO: implement swap1for0, or integrate it into this
    function swap0for1(uint amount0In, address to, bytes calldata data) external lock {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint16 _currentTick = currentTick;
        uint112 _virtualSupply = virtualSupply;

        uint112 totalAmountOut = 0;

        uint112 amountInLeft = uint112(amount0In);

        while (amountInLeft > 0) {
            FixedPoint.uq112x112 memory price = getTickPrice(_currentTick);

            // compute how much would need to be traded to get to the next tick down
            uint112 maxAmount = getTradeToRatio(_reserve0, _reserve1, price);
        
            uint112 amountToTrade = (amountInLeft > maxAmount) ? maxAmount : amountInLeft;

            // execute the sell of amountToTrade
            uint112 adjustedAmountToTrade = amountToTrade * (10000 - lpFee) / 10000;
            uint112 amountOut = (adjustedAmountToTrade * _reserve1) / (_reserve0 + adjustedAmountToTrade);
            _reserve0 -= amountOut;
            // TODO: handle overflow?
            _reserve1 += amountToTrade;

            amountInLeft = amountInLeft - amountToTrade;
            if (amountInLeft == 0) { // shift past the tick
                FixedPoint.uq112x112 memory k = Math.sqrt(uint(_reserve0) * uint(_reserve1)) / virtualSupply;
                TickInfo memory _oldTickInfo = tickInfos[_currentTick];
                FixedPoint.uq112x112 memory _oldKGrowthOutside = _oldTickInfo.kGrowthOutside ? _oldTickInfo.kGrowthOutside : FixedPoint.encode(uint112(1));
                Delta _delta = deltas[_currentTick];
                // TODO: mint protocol fee (in some way that batches the updates across multiple ticks)
                // kick out liquidity
                uint112 tokensOut = (uint(reserve0) * uint(_delta.sharesOut)) / uint(_virtualSupply);
                _reserve0 -= tokensOut;
                _reserve1 -= (reserve1 * _delta.sharesOut) / _virtualSupply;
                _virtualSupply -= _delta.sharesOut;
                // kick in liquidity
                uint112 sharesIn = uint112((uint(_virtualSupply) * uint(uint_delta.tokensIn)) / uint(_reserve0));
                _virtualSupply += sharesIn;
                _reserve0 += _delta.tokensIn;
                _reserve1 += price.mul112(_delta.tokensIn);
                // update the deltas
                deltas[_currentTick] = Delta({
                    sharesOut: sharesIn,
                    tokensIn: tokensOut
                });
                // update tick info
                tickInfos[_currentTick] = TickInfo({
                    // TODO: the overflow trick may not work here... we may need to switch to uint40 for timestamp
                    secondsGrowthOutside: uint32(block.timestamp % 2**32) - uint32(timeInitialized) - _oldTickInfo.secondsGrowthOutside,
                    kGrowthOutside: k.uqdiv112(_oldKGrowthOutside)
                });
                _currentTick -= 1;
            }
        }
        currentTick = _currentTick;
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        if (data.length > 0) IUniswapV3Callee(to).uniswapV3Call(msg.sender, 0, totalAmountOut, data);
        TransferHelper.safeTransferFrom(token0, msg.sender, address(this), amount0In);
        
        // TODO: emit event, update oracle, etc
    }

    function getTickPrice(uint16 index) public pure returns (FixedPoint.uq112x112 memory) {
        // returns a UQ112x112 representing the price of token0 in terms of token1, at the tick with that index

        // TODO: fix this
        int16 signedIndex = (int32(index) - 2**15);

        if (index == 0) {
            return FixedPoint.encode(1);
        }

        // compute 1.01^abs(index)
        // TODO: improve and fix this math, which is currently totally wrong
        // adapted from https://ethereum.stackexchange.com/questions/10425/is-there-any-efficient-way-to-compute-the-exponentiation-of-a-fraction-and-an-in
        FixedPoint.uq112x112 memory price = FixedPoint.encode(0);
        FixedPoint.uq112x112 memory N = FixedPoint.encode(1);
        uint112 B = 1;
        uint112 q = 100;
        uint precision = 50;
        for (uint i = 0; i < precision; ++i){
            price.add(N.div(B).div(q));
            N  = N.mul112(uint112(signedIndex - int16(i)));
            B = B * uint112(i+1);
            q = q * 100;
        }

        if (signedIndex < 0) {
            return price.reciprocal();
        }

        return price;
    }
}
