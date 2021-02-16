// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import './OracleTest.sol';

contract OracleGasTest {
    OracleTest oracle;

    constructor() {
        oracle = new OracleTest();
    }

    function initialize(OracleTest.InitializeParams calldata params) external {
        oracle.initialize(params);
    }

    function grow(uint16 cardinalityNext) external {
        oracle.grow(cardinalityNext);
    }

    function update(OracleTest.UpdateParams calldata params) external {
        oracle.update(params);
    }

    function advanceTime(uint32 by) external {
        oracle.advanceTime(by);
    }

    // return the difference between making multiple observe calls and making a single observeMultiple call
    function getGasCostOverhead(uint32[] calldata secondsAgos) external view returns (int256) {
        uint256 gasBefore0 = gasleft();
        {
            (int56[] memory tickCumulatives, uint160[] memory liquidityCumulatives) =
                oracle.observeMultiple(secondsAgos);
        }
        uint256 gasBefore1 = gasleft();
        for (uint256 i = 0; i < secondsAgos.length; i++) {
            oracle.observe(secondsAgos[i]);
        }
        uint256 gasIterative = gasBefore1 - gasleft();
        uint256 gasMultiple = gasBefore0 - gasBefore1;
        return int256(gasMultiple) - int256(gasIterative);
    }
}
