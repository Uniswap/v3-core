// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;
pragma abicoder v2;

import '../libraries/Oracle.sol';

contract OracleTest {
    using Oracle for Oracle.Observation[1024];

    uint256 public blockTimestamp;

    function setBlockTimestamp(uint256 _blockTimestamp) external {
        blockTimestamp = _blockTimestamp;
    }

    Oracle.Observation[1024] private observations;

    function setOracle(Oracle.Observation[] calldata _oracle, uint16 offset) external {
        for (uint16 i; i < _oracle.length; i++) {
            observations[i + offset] = _oracle[i];
        }
    }

    // somewhat fragile, copied from the pair
    function getObservations(uint16[] calldata indices) external view returns (Oracle.Observation[] memory o) {
        o = new Oracle.Observation[](indices.length);
        for (uint16 i; i < indices.length; i++) o[i] = observations[indices[i]];
    }

    // somewhat fragile, copied from the pair
    function scry(uint256 _blockTimestamp, uint16 index) external view returns (uint16 indexAtOrAfter) {
        require(_blockTimestamp <= blockTimestamp, 'BT'); // can't look into the future

        Oracle.Observation memory oldest = observations[(index + 1) % Oracle.CARDINALITY];

        // first, ensure that the oldest known observation is initialized
        if (oldest.initialized == false) {
            oldest = observations[0];
            require(oldest.initialized, 'UI');
        }

        uint32 target = uint32(_blockTimestamp);
        uint32 current = uint32(blockTimestamp);

        // then, ensure that the target is greater than the oldest observation (accounting for wrapping)
        require(oldest.blockTimestamp < target || (oldest.blockTimestamp > current && target <= current), 'OLD');

        uint256 newestBlockTimestamp = observations[index].blockTimestamp;

        // we can short-circuit for the specific case where the target is the block.timestamp, but an interaction
        // updated the oracle before this check, as this might be fairly common and is a worst-case for the binary search
        if (newestBlockTimestamp == target) return index;

        // adjust the newest and target block timestamps
        uint256 targetAdjusted = target;
        if (newestBlockTimestamp > current && targetAdjusted <= current) targetAdjusted += 2**32;
        if (targetAdjusted > current) newestBlockTimestamp += 2**32;

        // we can short-circuit if the target is after the youngest observation and return the current values
        if (newestBlockTimestamp < targetAdjusted) return Oracle.CARDINALITY; // special return value

        return observations.scry(target, index);
    }
}
