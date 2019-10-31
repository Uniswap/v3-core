pragma solidity 0.5.12;

import "../interfaces/IUniswapV2.sol";

import "../libraries/Math.sol";

contract Oracle {
    using Math for uint256;

    struct TokenData {
        uint128 token0;
        uint128 token1;
    }

    struct TimeData {
        uint64 blockNumber;
        uint64 blockTimestamp;
    }

    address public exchange;
    bool public initialized;
    uint64 constant period = 1 days;

    TokenData private reservesCumulative;
    TimeData private lastUpdate;

    TokenData private currentPrice;

    constructor(address _exchange) public {
        exchange = _exchange;
    }

    function _updateCurrentPrice(TokenData memory averages, uint64 timeElapsed) private {
        TokenData memory nextPrice;
        if (timeElapsed >= period || (currentPrice.token0 == 0 && currentPrice.token1 == 0)) {
            nextPrice = averages;
        } else {
            nextPrice = TokenData({
                token0: (currentPrice.token0 * (period - timeElapsed) + averages.token0 * timeElapsed) / period,
                token1: (currentPrice.token1 * (period - timeElapsed) + averages.token1 * timeElapsed) / period
            });
        }
        currentPrice = nextPrice;
    }

    function initialize() external {
        require(!initialized, "Oracle: ALREADY_INITIALIZED");

        IUniswapV2 uniswapV2 = IUniswapV2(exchange);
        (uint128 reserveCumulativeToken0, uint128 reserveCumulativeToken1) = uniswapV2.getReservesCumulative();

        reservesCumulative.token0 = reserveCumulativeToken0;
        reservesCumulative.token1 = reserveCumulativeToken1;
        lastUpdate.blockNumber = block.number.downcastTo64();
        lastUpdate.blockTimestamp = block.timestamp.downcastTo64();

        initialized = true;
    }

    function updateCurrentPrice() external {
        require(initialized, "Oracle: UNINITIALIZED");

        uint64 blockNumber = block.number.downcastTo64();
        // if we haven't updated this block yet...
        if (blockNumber > lastUpdate.blockNumber) {
            IUniswapV2 uniswapV2 = IUniswapV2(exchange);
            (uint128 reserveCumulativeToken0, uint128 reserveCumulativeToken1) = uniswapV2.getReservesCumulative();

            uint128 blocksElapsed = blockNumber - lastUpdate.blockNumber;

            TokenData memory deltas = TokenData({
                token0: reserveCumulativeToken0 - reservesCumulative.token0,
                token1: reserveCumulativeToken1 - reservesCumulative.token1
            });

            TokenData memory averages = TokenData({
                token0: deltas.token0 / blocksElapsed,
                token1: deltas.token1 / blocksElapsed
            });

            uint64 blockTimestamp = block.timestamp.downcastTo64();
            uint64 timeElapsed = blockTimestamp - lastUpdate.blockTimestamp;
            _updateCurrentPrice(averages, timeElapsed);

            reservesCumulative.token0 = reserveCumulativeToken0;
            reservesCumulative.token1 = reserveCumulativeToken1;
            lastUpdate.blockNumber = blockNumber;
            lastUpdate.blockTimestamp = blockTimestamp;
        }
    }

    function getCurrentPrice() external view returns (uint128, uint128) {
        return (currentPrice.token0, currentPrice.token1);
    }
}
