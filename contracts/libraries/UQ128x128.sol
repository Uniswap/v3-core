pragma solidity 0.5.12;

// helpful links
// https://en.wikipedia.org/wiki/Q_(number_format)
// https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.md
// https://github.com/gnosis/solidity-arithmetic

library UQ128x128 {
    uint constant Q128 = 2**128;

    // we want to encode a uint128 `y` s.t. `y := y_encoded / 2**128` (i.e. with a Q128 denominator).
    // in other words, to encode `y` we simply multiply by `2**128`, aka Q104, and store this in a 208-bit slot.
    function encode(uint128 y) internal pure returns (uint z) {
        return uint(y) * Q128; // guaranteed not to overflow
    }

    // we want to divide a UQ128.128 (the output of encode above) by an unencoded uint128 and return another
    // modified UQ128.128. to do this, it's sufficient to divide the UQ128.128 by the unencoded value.
    function qdiv(uint x, uint128 y) internal pure returns (uint z) {
        z = x / y;
    }
}
