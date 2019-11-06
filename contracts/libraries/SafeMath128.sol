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

    function oadd(uint128 w, uint128 x) internal pure returns (uint128 y, uint128 z) {
        uint256 sum = uint256(w) + x;
        z = uint128(sum / uint128(-1));
        y = uint128(sum % uint128(-1));
    }
    function omul(uint128 w, uint128 x) internal pure returns (uint128 y, uint128 z) {
        uint256 product = uint256(w) * x;
        z = uint128(product / uint128(-1));
        y = uint128(product % uint128(-1));
    }
}
