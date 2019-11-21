pragma solidity 0.5.12;

// mock fixed- or floating-point math
library MOCK_Decimal {
    struct Decimal {
        uint256 data;
    }

    function div(uint128 numerator, uint128 denominator) internal pure returns (Decimal memory) {
        return Decimal(numerator / denominator);
    }

    function mul(Decimal memory a, uint128 b) internal pure returns (Decimal memory) {
        return Decimal(a.data * b);
    }

    function add(Decimal memory a, Decimal memory b) internal pure returns (Decimal memory) {
        return Decimal(a.data + b.data);
    }
}
