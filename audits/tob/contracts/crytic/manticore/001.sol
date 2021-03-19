import '../../../../../contracts/libraries/BitMath.sol';

contract VerifyBitMathMsb {
    function verify(uint256 x) external {
        uint256 msb = BitMath.mostSignificantBit(x);

        bool property = x >= 2**msb && (msb == 255 || x < 2**(msb + 1));

        require(!property);
    }
}
