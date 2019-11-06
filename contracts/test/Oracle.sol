pragma solidity 0.5.12;

import "../interfaces/IUniswapV2.sol";

import "../libraries/SafeMath256.sol";

contract Oracle {
    using SafeMath256 for uint256;

    enum OracleStates { NeedsInitialization, NeedsActivation, Active }

    struct TokenData {
        uint128 token0;
        uint128 token1;
    }

    struct TimeData {
        uint128 blockNumber;
        uint128 blockTimestamp;
    }

    address public exchange;
    uint128 constant period = 1 days;

    OracleStates private state = OracleStates.NeedsInitialization;
    TokenData private reservesCumulative;
    TimeData private lastUpdate;
    TokenData private currentPrice;

    constructor(address _exchange) public {
        exchange = _exchange;
    }

    function getReservesCumulative() private view returns (TokenData memory) {
        IUniswapV2 uniswapV2 = IUniswapV2(exchange);
        (uint128 reservesCumulativeToken0, uint128 reservesCumulativeToken1,,) = uniswapV2.getReservesCumulativeAndOverflows();
        return TokenData({
            token0: reservesCumulativeToken0,
            token1: reservesCumulativeToken1
        });
    }

    function getTimeData() private view returns (TimeData memory) {
        return TimeData({
            blockNumber: block.number.downcast128(),
            blockTimestamp: block.timestamp.downcast128()
        });
    }

    function initialize() external {
        require(state == OracleStates.NeedsInitialization, "Oracle: DOES_NOT_NEED_INITIALIZATION");

        reservesCumulative = getReservesCumulative();
        lastUpdate = getTimeData();

        state = OracleStates.NeedsActivation;
    }

    function activate() external {
        require(state == OracleStates.NeedsActivation, "Oracle: DOES_NOT_NEED_ACTIVATION");

        // get the current time, ensure it's been >=1 blocks since last update, and record the update
        TimeData memory currentTime = getTimeData();
        uint128 blocksElapsed = currentTime.blockNumber - lastUpdate.blockNumber;
        require(blocksElapsed > 0, "Oracle: INSUFFICIENT_BLOCKS_PASSED");
        lastUpdate = currentTime;

        // get the current cumulative reserves, calculate the deltas, and record the new values
        TokenData memory reservesCumulativeNext = getReservesCumulative();
        TokenData memory deltas = TokenData({
            token0: reservesCumulativeNext.token0 - reservesCumulative.token0,
            token1: reservesCumulativeNext.token1 - reservesCumulative.token1
        });
        reservesCumulative = reservesCumulativeNext;

        // get the average price over the period and set it to the current price
        currentPrice = TokenData({
            token0: deltas.token0 / blocksElapsed,
            token1: deltas.token1 / blocksElapsed
        });

        state = OracleStates.Active;
    }

    function update() external {
        require(state == OracleStates.Active, "Oracle: INACTIVE");

        // get the current time, ensure it's been >=1 blocks since last update, and record the update
        TimeData memory currentTime = getTimeData();
        uint128 blocksElapsed = currentTime.blockNumber - lastUpdate.blockNumber;
        require(blocksElapsed > 0, "Oracle: INSUFFICIENT_BLOCKS_PASSED");
        uint128 timeElapsed = currentTime.blockTimestamp - lastUpdate.blockTimestamp;
        lastUpdate = currentTime;

        // get the current cumulative reserves, calculate the deltas, and record the new values
        TokenData memory reservesCumulativeNext = getReservesCumulative();
        TokenData memory deltas = TokenData({
            token0: reservesCumulativeNext.token0 - reservesCumulative.token0,
            token1: reservesCumulativeNext.token1 - reservesCumulative.token1
        });
        reservesCumulative = reservesCumulativeNext;

        // get the average price over the period
        TokenData memory averages = TokenData({
            token0: deltas.token0 / blocksElapsed,
            token1: deltas.token1 / blocksElapsed
        });

        // update the current price with this information
        if (timeElapsed < period) {
            currentPrice = TokenData({
                token0: (currentPrice.token0 * (period - timeElapsed) + averages.token0 * timeElapsed) / period,
                token1: (currentPrice.token1 * (period - timeElapsed) + averages.token1 * timeElapsed) / period
            });
        } else {
            currentPrice = averages;
        }
    }

    function getCurrentPrice() external view returns (uint128, uint128) {
        return (currentPrice.token0, currentPrice.token1);
    }
}
