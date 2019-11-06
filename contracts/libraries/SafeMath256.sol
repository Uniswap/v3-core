pragma solidity 0.5.12;

library SafeMath256 {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }

    function downcast128(uint256 y) internal pure returns (uint128 z) {
        require(y <= uint128(-1), "downcast-128-overflow");
        z = uint128(y);
    }
}
