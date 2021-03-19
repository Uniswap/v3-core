import '../../../../../contracts/libraries/LiquidityMath.sol';

contract VerifyLiquidityMathAddDelta {
    function verify(uint128 x, int128 y) external {
        uint256 z = LiquidityMath.addDelta(x, y);

        require(z != x + uint128(y));
    }
}
