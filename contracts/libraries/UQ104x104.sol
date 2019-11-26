pragma solidity 0.5.12;

// helpful links
// https://en.wikipedia.org/wiki/Q_(number_format)
// https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.md
// https://github.com/gnosis/solidity-arithmetic

library UQ104x104 {
    uint240 constant Q104 = 2**104;

    // we want to encode a uint128 `y` s.t. `y := y_encoded / 2**104` (i.e. with a Q104 denominator).
    // in other words, to encode `y` we simply multiply by `2**104`, aka Q104.
    // however, in the case of a traditional UQ104.104, we'd store this output in a 208-bit slot,
    // which would overflow for values of `y` in (`uint104(-1)`, `uint128(-1)`], so instead we need to
    // store the output in 232 bits (TODO check this logic).
    function encode(uint128 y) internal pure returns (uint240 z) {
        return uint240(y) * Q104;
    }

    // we want to divide a modified UQ104.104 (the output of encode) by an unencoded uint128,
    // and return a traditional Q104. since we're using a modified UQ104.104, though, we need to handle overflows.
    // for the moment, we simply truncate these to 1 and uint208(-1), though it's likely we'll handle this slightly
    // differently in the future
    function qdiv(uint240 x, uint128 y) internal pure returns (uint240 z) {
        z = x / y;
        
        if (z == 0) {
            z = 1;
        } else if (z > uint208(-1)) {
            z = uint208(-1);
        }
    }
}
