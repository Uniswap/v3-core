import '../../../../../contracts/libraries/BitMath.sol';

contract VerifyBitMathLsb {
    function verify(uint256 x) external {
        uint256 lsb = BitMath.leastSignificantBit(x);

        // (x & 2**leastSignificantBit(x)) != 0 and (x & (2**(leastSignificantBit(x)) - 1)) == 0)
        bool property = ((x & (2**lsb)) != 0) && ((x & (2**(lsb - 1))) == 0);

        require(!property);
    }
}
