pragma solidity 0.5.12;

import "../interfaces/IUniswapV2.sol";

contract Oracle {
    struct TokenData {
        uint128 token0;
        uint128 token1;
    }

    struct Time {
        uint64 blockNumber;
        uint64 blockTimestamp;
    }

    address public exchange;
    uint128 constant period = 1 days;

    TokenData private reservesCumulative;
    Time private lastUpdate;
    TokenData private currentPrice;

    constructor(address _exchange) public {
        exchange = _exchange;
    }

    function _updateCurrentPrice(TokenData memory averages, uint128 timestampDelta) private {
        TokenData memory nextPrice;
        if (timestampDelta >= period || (currentPrice.token0 == 0 && currentPrice.token1 == 0)) {
            nextPrice = averages;
        } else {
            nextPrice = TokenData({
                token0: (currentPrice.token0 * (period - timestampDelta) + averages.token0 * timestampDelta) / period,
                token1: (currentPrice.token1 * (period - timestampDelta) + averages.token1 * timestampDelta) / period
            });
        }
        currentPrice = nextPrice;
    }

    function updateCurrentPrice() external {
        IUniswapV2 uniswapV2 = IUniswapV2(exchange);
        // TODO handle the case where time has passed (basically, always use the most up-to-date data)
        (uint128 reserveCumulativeToken0, uint128 reserveCumulativeToken1) = uniswapV2.getReservesCumulative();
        (uint64 blockNumber, uint64 blockTimestamp) = uniswapV2.getLastUpdate();

        if (blockNumber > lastUpdate.blockNumber) {
            uint128 blocksElapsed = blockNumber - lastUpdate.blockNumber;

            if (lastUpdate.blockNumber != 0) {
                TokenData memory deltas = TokenData({
                    token0: reserveCumulativeToken0 - reservesCumulative.token0,
                    token1: reserveCumulativeToken1 - reservesCumulative.token1
                });

                TokenData memory averages = TokenData({
                    token0: deltas.token0 / blocksElapsed,
                    token1: deltas.token1 / blocksElapsed
                });

                uint128 timeElapsed = blockTimestamp - lastUpdate.blockTimestamp;
                _updateCurrentPrice(averages, timeElapsed);
            }

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
