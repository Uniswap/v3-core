pragma solidity 0.5.12;

library SafeMath128 {
    function add(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }
    function sub(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }
    function mul(uint128 x, uint128 y) internal pure returns (uint128 z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }
}
