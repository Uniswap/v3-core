// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2f9ae975c8bdc5c7f7fa26204896f6c717f07164/contracts/math/SafeMath.sol
pragma solidity 0.5.12;

library SafeMath256 {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a, "SafeMath256: addition overflow");
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath256: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) return 0;
        c = a * b;
        require(c / a == b, "SafeMath256: multiplication overflow");
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath256: division by zero");
        return a / b;
    }
}
