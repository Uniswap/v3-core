// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2f9ae975c8bdc5c7f7fa26204896f6c717f07164/contracts/math/SafeMath.sol
pragma solidity 0.5.12;

library SafeMath128 {
    function add(uint128 a, uint128 b) internal pure returns (uint128 c) {
        c = a + b;
        require(c >= a, "SafeMath128: addition overflow");
    }

    function sub(uint128 a, uint128 b) internal pure returns (uint128) {
        require(b <= a, "SafeMath128: subtraction overflow");
        return a - b;
    }

    function mul(uint128 a, uint128 b) internal pure returns (uint128 c) {
        if (a == 0) return 0;
        c = a * b;
        require(c / a == b, "SafeMath128: multiplication overflow");
    }

    function div(uint128 a, uint128 b) internal pure returns (uint128) {
        require(b > 0, "SafeMath128: division by zero");
        return a / b;
    }
}
