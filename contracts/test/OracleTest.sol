// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import '../libraries/Oracle.sol';

contract OracleTest {
    using Oracle for Oracle.Observation[65535];

    Oracle.Observation[65535] public observations;

    uint32 public time;
    int24 public tick;
    uint128 public liquidity;
    uint16 public index;
    uint16 public cardinality = 1024;
    uint16 public target = 1024;

    constructor() {
        observations[0] = Oracle.Observation({
            blockTimestamp: time,
            tickCumulative: 0,
            liquidityCumulative: 0,
            initialized: true
        });
    }

    function setObservations(
        Oracle.Observation[] calldata _observations,
        uint16 offset,
        uint16 _index
    ) external {
        for (uint16 i; i < _observations.length; i++) observations[i + offset] = _observations[i];
        index = _index;
    }

    function getGasCostOfScry(uint32 secondsAgo) external view returns (uint256) {
        (uint32 _time, int24 _tick, uint128 _liquidity, uint16 _index) = (time, tick, liquidity, index);
        uint256 gasBefore = gasleft();
        observations.scry(_time, secondsAgo, _tick, _index, _liquidity, cardinality);
        return gasBefore - gasleft();
    }

    function setOracleData(
        uint32 _time,
        int24 _tick,
        uint128 _liquidity,
        uint16 _cardinality,
        uint16 _target
    ) external {
        time = _time;
        tick = _tick;
        liquidity = _liquidity;
        cardinality = _cardinality;
        target = _target;
    }

    function advanceTime(uint32 by) external {
        time += by;
    }

    // write an observation, then change tick and liquidity
    function write(int24 _tick, uint128 _liquidity) external {
        (index, cardinality) = observations.write(index, time, tick, liquidity, cardinality, target);
        tick = _tick;
        liquidity = _liquidity;
    }

    function scry(uint32 secondsAgo) external view returns (int56 tickCumulative, uint160 liquidityCumulative) {
        return observations.scry(time, secondsAgo, tick, index, liquidity, cardinality);
    }
}
