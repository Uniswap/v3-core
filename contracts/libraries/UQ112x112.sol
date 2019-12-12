pragma solidity 0.5.14;

library UQ112x112 {
    uint224 constant Q112 = 2**112;

    // encode a uint112 as a UQ112.112 fixed point number s.t. `y := z / 2**112`
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112.112 by a uint112 and return the result as a UQ112.112
    function qdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / y;
    }
}
