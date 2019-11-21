pragma solidity 0.5.12;

// TODO this whole library is basically just a mock at the moment
library UQ104x104 {
    uint208 constant Q104 = uint104(-1);

    function encode(uint128 y) internal pure returns (uint208 z) {
        // require(y <= Q104, "encode-overflow");
        z = y * Q104;
    }
    function qmul(uint208 x, uint208 y) internal pure returns (uint208 z) {
        z = x * y / Q104;
    }
    function qdiv(uint208 x, uint208 y) internal pure returns (uint208 z) {
        z = x / y;
    }
}
