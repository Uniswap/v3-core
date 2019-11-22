pragma solidity 0.5.12;

// helpful links
// https://en.wikipedia.org/wiki/Q_(number_format)
// https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.md
// https://github.com/gnosis/solidity-arithmetic

library UQ104x104 {
    uint232 constant Q104 = uint232(uint104(-1)) + 1;

    // we want to encode a uint128 `y` s.t. `y := y_encoded / 2**104` (i.e. with a Q104 denominator).
    // in other words, to encode `y` we simply multiply by `2**104`, aka Q104.
    // however, in the case of a traditional UQ104.104, we'd store this output in a 208-bit slot,
    // which would overflow for values of `y` in (`uint104(-1)`, `uint128(-1)`], so instead we need to
    // store the output in 232 bits (TODO check this logic).
    function encode(uint128 y) internal pure returns (uint232 z) {
        return uint232(y) * Q104;
    }

    // we want to divide two modified-UQ104.104s (the outputs of encode), and return a traditional Q104.
    // for our purposes, we'll do that by flooring the output of the division with `uint208(-1)`.
    // (this corresponds to capping the relative prices of x and y at `1 / 2**104` and `uint208(-1) / 2**104`.)
    // unfortunately, before we can compute `min(uint208(-1), output), we need to compute `output = x * 2**104 / y`,
    // for which we need at least 416 bits (possibly 438 or 464? TODO think this through).
    // for now, we just mock the function
    function qdiv(uint232 x, uint232 y) internal pure returns (uint208 z) {
        // TODO replace mock with real logic
        z = uint208(x * Q104 / y);
    }
}
