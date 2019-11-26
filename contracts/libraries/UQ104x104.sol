pragma solidity 0.5.12;

// helpful links
// https://en.wikipedia.org/wiki/Q_(number_format)
// https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.md
// https://github.com/gnosis/solidity-arithmetic

library UQ104x104 {
    uint240 constant Q104 = 2**104;

    // we want to encode a uint128 `y` s.t. `y := y_encoded / 2**104` (i.e. with a Q104 denominator).
    // in other words, to encode `y` we simply multiply by `2**104`, aka Q104.
    // in the case of a traditional UQ104.104, we'd store this output in a 208-bit slot,
    // but since we're encoding a uint128, this would overflow for values of `y` in (`uint104(-1)`, `uint128(-1)`],
    // so instead we need to store the output in at least 232 bits (we use 240 for compatibility later on)
    function encode(uint128 y) internal pure returns (uint240 z) {
        return uint240(y) * Q104;
    }

    // we want to divide a modified UQ104.104 (the output of encode above) by an unencoded uint128 and return another
    // modified UQ104.104. to do this, it's sufficient to divide the UQ104.104 by the unencoded value.
    // since we want our output to fit in 208 bits, and behave consistently at the margins, we clamp this quotient
    // within [1, uint208(-1)]
    function qdiv(uint240 x, uint128 y) internal pure returns (uint240 z) {
        z = x / y;

        if (z == 0) {
            z = 1;
        } else if (z > uint208(-1)) {
            z = uint208(-1);
        }
    }
}
