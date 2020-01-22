pragma solidity =0.5.16;

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x <= y ? x : y;
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            uint x = y / 2 + 1;
            z = y;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
