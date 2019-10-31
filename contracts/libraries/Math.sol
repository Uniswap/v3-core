pragma solidity 0.5.12;

library Math {
    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2f9ae975c8bdc5c7f7fa26204896f6c717f07164/contracts/math/Math.sol#L17
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // https://github.com/ethereum/dapp-bin/pull/50
    // https://github.com/ethereum/dapp-bin/blob/11f05fc9e3f31a00d57982bc2f65ef2654f1b569/library/math.sol#L28
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) {
            y = 0;
        } else if (x <= 3) {
            y = 1;
        } else {
            y = x;
            uint256 z = (x + 1) / 2;
            while (z < y) {
                y = z;
                z = (x / z + z) / 2;
            }
        }
    }

    function downcastTo64(uint256 a) internal pure returns (uint64) {
        require(a <= uint64(-1), "Math: downcast overflow (uint256 to uint64)");
        return uint64(a);
    }

    function downcastTo128(uint256 a) internal pure returns (uint128) {
        require(a <= uint128(-1), "Math: downcast overflow (uint256 to uint128)");
        return uint128(a);
    }
}
