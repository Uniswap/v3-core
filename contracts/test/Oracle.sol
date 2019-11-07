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
    TokenData private reservesCumulativeOverflows;

    TokenData private currentPrice;

    TimeData private updateLast;

    constructor(address _exchange) public {
        exchange = _exchange;
    }

    function getReservesCumulative() private view returns (TokenData memory, TokenData memory) {
        (
            uint128 reservesCumulativeToken0,
            uint128 reservesCumulativeToken1,
            uint128 reservesCumulativeOverflowsToken0,
            uint128 reservesCumulativeOverflowsToken1
        ) = IUniswapV2(exchange).getReservesCumulative();
        return (
            TokenData(reservesCumulativeToken0, reservesCumulativeToken1),
            TokenData(reservesCumulativeOverflowsToken0, reservesCumulativeOverflowsToken1)
        );
    }

    function getNow() private view returns (TimeData memory) {
        return TimeData(block.number.downcast128(), block.timestamp.downcast128());
    }

    function reset() private {
        delete(reservesCumulative);
        delete(reservesCumulativeOverflows);
        delete(currentPrice);
        delete(updateLast);
        state = OracleStates.NeedsInitialization;
    }

    function initialize() external {
        require(state == OracleStates.NeedsInitialization, "Oracle: DOES_NOT_NEED_INITIALIZATION");

        (reservesCumulative, reservesCumulativeOverflows) = getReservesCumulative();
        updateLast = getNow();

        state = OracleStates.NeedsActivation;
    }

    function activate() external {
        require(state == OracleStates.NeedsActivation, "Oracle: DOES_NOT_NEED_ACTIVATION");

        // get the current time, ensure it's been >=1 blocks since the last update
        TimeData memory _now = getNow();
        uint128 blocksElapsed = _now.blockNumber - updateLast.blockNumber;
        require(blocksElapsed > 0, "Oracle: INSUFFICIENT_BLOCKS_PASSED");

        // get the current cumulative reserves and overflows
        TokenData memory reservesCumulativeNext;
        TokenData memory reservesCumulativeOverflowsNext;
        (reservesCumulativeNext, reservesCumulativeOverflowsNext) = getReservesCumulative();

        // reset if there's been an overflow
        if (
            reservesCumulativeOverflows.token0 != reservesCumulativeOverflowsNext.token0 ||
            reservesCumulativeOverflows.token1 != reservesCumulativeOverflowsNext.token1
        ) {
            reset();
            require(false, "Oracle: OVERFLOW");
        }

        // calculate the deltas, and record the new values
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

        updateLast = _now;

        state = OracleStates.Active;
    }

    function update() external {
        require(state == OracleStates.Active, "Oracle: INACTIVE");

        // get the current time, ensure it's been >=1 blocks since the last update
        TimeData memory _now = getNow();
        uint128 blocksElapsed = _now.blockNumber - updateLast.blockNumber;
        require(blocksElapsed > 0, "Oracle: INSUFFICIENT_BLOCKS_PASSED");
        uint128 timeElapsed = _now.blockTimestamp - updateLast.blockTimestamp;

        // get the current cumulative reserves and overflows
        TokenData memory reservesCumulativeNext;
        TokenData memory reservesCumulativeOverflowsNext;
        (reservesCumulativeNext, reservesCumulativeOverflowsNext) = getReservesCumulative();

        // reset if there's been an overflow
        if (
            reservesCumulativeOverflows.token0 != reservesCumulativeOverflowsNext.token0 ||
            reservesCumulativeOverflows.token1 != reservesCumulativeOverflowsNext.token1
        ) {
            reset();
            require(false, "Oracle: OVERFLOW");
        }

        // calculate the deltas, and record the new values
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

        updateLast = _now;
    }

    function getCurrentPrice() external view returns (uint128, uint128) {
        return (currentPrice.token0, currentPrice.token1);
    }
}
