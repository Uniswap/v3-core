// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import './OracleTest.sol';

contract OracleEchidnaTest {
    OracleTest private oracle;

    bool private initialized;
    uint32 private timePassed;

    constructor() {
        oracle = new OracleTest();
    }

    function initialize(
        uint32 time,
        int24 tick,
        uint128 liquidity
    ) external {
        oracle.initialize(OracleTest.InitializeParams({time: time, tick: tick, liquidity: liquidity}));
        initialized = true;
    }

    function limitTimePassed(uint32 by) private {
        require(timePassed + by >= timePassed);
        timePassed += by;
    }

    function advanceTime(uint32 by) public {
        limitTimePassed(by);
        oracle.advanceTime(by);
    }

    // write an observation, then change tick and liquidity
    function update(
        uint32 advanceTimeBy,
        int24 tick,
        uint128 liquidity
    ) external {
        limitTimePassed(advanceTimeBy);
        oracle.update(OracleTest.UpdateParams({advanceTimeBy: advanceTimeBy, tick: tick, liquidity: liquidity}));
    }

    function grow(uint16 cardinality) external {
        oracle.grow(cardinality);
    }

    function checkTimeWeightedResultAssertions(uint32 secondsAgo0, uint32 secondsAgo1) private view {
        require(secondsAgo0 != secondsAgo1);
        require(initialized);
        // secondsAgo0 should be the larger one
        if (secondsAgo0 < secondsAgo1) (secondsAgo0, secondsAgo1) = (secondsAgo1, secondsAgo0);

        uint32 timeElapsed = secondsAgo0 - secondsAgo1;

        (int56 tickCumulative0, uint160 liquidityCumulative0) = oracle.observe(secondsAgo0);
        (int56 tickCumulative1, uint160 liquidityCumulative1) = oracle.observe(secondsAgo1);
        int56 timeWeightedTick = (tickCumulative1 - tickCumulative0) / timeElapsed;
        uint160 timeWeightedLiquidity = (liquidityCumulative1 - liquidityCumulative0) / timeElapsed;
        assert(timeWeightedLiquidity <= type(uint128).max);
        assert(timeWeightedTick <= type(int24).max);
        assert(timeWeightedTick >= type(int24).min);
    }

    function echidna_indexAlwaysLtCardinality() external view returns (bool) {
        return oracle.index() < oracle.cardinality() || !initialized;
    }

    function echidna_AlwaysInitialized() external view returns (bool) {
        (, , , bool isInitialized) = oracle.observations(0);
        return oracle.cardinality() == 0 || isInitialized;
    }

    function echidna_cardinalityAlwaysLteNext() external view returns (bool) {
        return oracle.cardinality() <= oracle.cardinalityNext();
    }

    function echidna_canAlwaysObserve0IfInitialized() external view returns (bool) {
        if (!initialized) {
            return true;
        }
        (bool success, ) = address(oracle).staticcall(abi.encodeWithSelector(OracleTest.observe.selector, 0));
        return success;
    }

    function checkTwoAdjacentObservationsModTimeElapsedAlways0(uint16 index) external view {
        uint16 cardinality = oracle.cardinality();
        require(index < cardinality && index != (oracle.index() + 1) % cardinality);

        (uint32 blockTimestamp0, int56 tickCumulative0, uint160 liquidityCumulative0, bool initialized0) =
            oracle.observations(index == 0 ? cardinality - 1 : index - 1);
        (uint32 blockTimestamp1, int56 tickCumulative1, uint160 liquidityCumulative1, bool initialized1) =
            oracle.observations(index);

        require(initialized0);
        require(initialized1);

        uint32 timeElapsed = blockTimestamp1 - blockTimestamp0;
        assert(timeElapsed > 0);
        assert((tickCumulative1 - tickCumulative0) % timeElapsed == 0);
        assert((liquidityCumulative1 - liquidityCumulative0) % timeElapsed == 0);
    }

    function checkTimeWeightedAveragesAlwaysFitsType(uint32 secondsAgo) external view {
        require(initialized);
        require(secondsAgo > 0);
        (int56 tickCumulative0, uint160 liquidityCumulative0) = oracle.observe(secondsAgo);
        (int56 tickCumulative1, uint160 liquidityCumulative1) = oracle.observe(0);

        // compute the time weighted tick, rounding consistently
        int56 numerator = tickCumulative1 - tickCumulative0;
        int56 timeWeightedTick = numerator / int56(secondsAgo);
        if (numerator < 0 && numerator % int56(secondsAgo) != 0) {
            timeWeightedTick--;
        }

        // the time weighted averages fit in their respective accumulated types
        assert(timeWeightedTick <= type(int24).max && timeWeightedTick >= type(int24).min);
        assert((liquidityCumulative1 - liquidityCumulative0) / uint160(secondsAgo) <= type(uint128).max);
    }
}
