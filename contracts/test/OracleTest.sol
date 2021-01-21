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
    uint16 public cardinality;
    uint16 public target;

    struct InitializeParams {
        uint32 time;
        int24 tick;
        uint128 liquidity;
    }

    function initialize(InitializeParams calldata params) external {
        require(cardinality == 0, 'already initialized');
        time = params.time;
        tick = params.tick;
        liquidity = params.liquidity;
        (cardinality, target) = observations.initialize(params.time);
    }

    function advanceTime(uint32 by) public {
        time += by;
    }

    struct UpdateParams {
        uint32 advanceTimeBy;
        int24 tick;
        uint128 liquidity;
    }

    // write an observation, then change tick and liquidity
    function update(UpdateParams calldata params) external {
        advanceTime(params.advanceTimeBy);
        (index, cardinality) = observations.write(index, time, tick, liquidity, cardinality, target);
        tick = params.tick;
        liquidity = params.liquidity;
    }

    function batchUpdate(UpdateParams[] calldata params) external {
        // sload everything
        int24 _tick = tick;
        uint128 _liquidity = liquidity;
        uint16 _index = index;
        uint16 _cardinality = cardinality;
        uint16 _target = target;
        uint32 _time = time;

        for (uint256 i = 0; i < params.length; i++) {
            _time += params[i].advanceTimeBy;
            (_index, _cardinality) = observations.write(_index, _time, _tick, _liquidity, _cardinality, _target);
            _tick = params[i].tick;
            _liquidity = params[i].liquidity;
        }

        // sstore everything
        tick = _tick;
        liquidity = _liquidity;
        index = _index;
        cardinality = _cardinality;
        time = _time;
    }

    function grow(uint16 _target) external {
        (cardinality, target) = observations.grow(index, cardinality, target, _target);
    }

    function getGasCostOfScry(uint32 secondsAgo) external view returns (uint256) {
        (uint32 _time, int24 _tick, uint128 _liquidity, uint16 _index) = (time, tick, liquidity, index);
        uint256 gasBefore = gasleft();
        observations.scry(_time, secondsAgo, _tick, _index, _liquidity, cardinality);
        return gasBefore - gasleft();
    }

    function scry(uint32 secondsAgo) external view returns (int56 tickCumulative, uint160 liquidityCumulative) {
        return observations.scry(time, secondsAgo, tick, index, liquidity, cardinality);
    }
}
