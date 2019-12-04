pragma solidity 0.5.12;

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }

    function sqrt(uint x) internal pure returns (uint y) {
        if (x == 0) return 0;
        else if (x <= 3) return 1;
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
