pragma solidity 0.5.12;

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }

    function clamp128(uint y) internal pure returns (uint128 z) {
        z = y <= uint128(-1) ? uint128(y) : uint128(-1);
    }

    function downcast128(uint y) internal pure returns (uint128 z) {
        require(y <= uint128(-1), "downcast-128-overflow");
        z = uint128(y);
    }

    function downcast32(uint y) internal pure returns (uint32 z) {
        require(y <= uint32(-1), "downcast-32-overflow");
        z = uint32(y);
    }
}
