pragma solidity 0.5.13;

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y == 0) return 0;
        else if (y <= 3) return 1;
        uint x = (y + 1) / 2;
        z = y;
        while (x < z) {
            z = x;
            x = (y / x + x) / 2;
        }
    }
}
