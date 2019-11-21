pragma solidity 0.5.12;

// TODO this library is broken at the moment, and is meant only to serve as a mock
library UQ104x104 {
    uint208 constant Q104 = uint104(-1);

    function encode(uint128 y) internal pure returns (uint208 z) {
        require(y <= Q104, "encode-overflow");
        z = y * Q104;
    }
    function qdiv(uint208 x, uint208 y) internal pure returns (uint208 z) {
        uint256 quotient = uint256(x) / uint256(y);
        require(quotient <= Q104, "div-overflow");
        z = uint208(quotient * Q104);
    }
}
