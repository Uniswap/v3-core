pragma solidity 0.5.12;

library Math {
    // based on https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2f9ae975c8bdc5c7f7fa26204896f6c717f07164/contracts/math/Math.sol#L17
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // based on https://github.com/ethereum/dapp-bin/blob/11f05fc9e3f31a00d57982bc2f65ef2654f1b569/library/math.sol#L28 via https://github.com/ethereum/dapp-bin/pull/50
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        else if (x <= 3) return 1;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
