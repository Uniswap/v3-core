// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import './OracleTest.sol';

contract OracleEchidnaTest {
    OracleTest private oracle;

    bool initialized;
    uint32 timePassed;

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

    function grow(uint16 target) external {
        oracle.grow(target);
    }

    function echidna_indexAlwaysLtCardinality() external view returns (bool) {
        return oracle.index() < oracle.cardinality() || !initialized;
    }

    function echidna_cardinalityAlwaysLteTarget() external view returns (bool) {
        return oracle.cardinality() <= oracle.target();
    }
}
