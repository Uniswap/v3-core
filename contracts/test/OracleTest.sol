// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import '../libraries/Oracle.sol';

contract OracleTest {
    using Oracle for Oracle.Observation[65536];

    Oracle.Observation[65536] public observations;

    uint32 public time;
    int24 public tick;
    uint128 public liquidity;
    uint16 public index;
    uint16 public cardinality = 1024;
    uint16 public target = 1024;

    function setObservations(Oracle.Observation[] calldata _observations, uint16 offset) external {
        for (uint16 i; i < _observations.length; i++) observations[i + offset] = _observations[i];
    }

    function getGasCostOfObservationAt(uint32 secondsAgo) external view returns (uint256) {
        (uint32 _time, int24 _tick, uint128 _liquidity, uint16 _index) = (time, tick, liquidity, index);
        uint256 gasBefore = gasleft();
        observations.scry(_time, secondsAgo, _tick, _index, _liquidity, cardinality);
        return gasBefore - gasleft();
    }

    function setOracleData(
        int24 _tick,
        uint128 _liquidity,
        uint16 _index,
        uint32 _time,
        uint16 _cardinality,
        uint16 _target
    ) external {
        tick = _tick;
        liquidity = _liquidity;
        index = _index;
        time = _time;
        cardinality = _cardinality;
        target = _target;
    }

    function advanceTime(uint32 by) external {
        time += by;
    }

    // write an observation, then change tick and liquidity
    function write(int24 _tick, uint128 _liquidity) external {
        index = observations.write(index, time, tick, liquidity, cardinality);
        tick = _tick;
        liquidity = _liquidity;
    }

    function scry(uint32 secondsAgo) external view returns (int56 tickCumulative, uint160 liquidityCumulative) {
        return observations.scry(time, secondsAgo, tick, index, liquidity, cardinality);
    }
}
