pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

import '../libraries/TickMath.sol';
import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

contract TickMathTest {
    function getPrice(int16 tick) public pure returns (FixedPoint.uq112x112 memory) {
        return TickMath.getRatioAtTick(tick);
    }

    function getGasUsed(int16 tick) view public returns (uint) {
        uint gasBefore = gasleft();
        TickMath.getRatioAtTick(tick);
        uint gasAfter = gasleft();
        return (gasBefore - gasAfter);
    }
}
