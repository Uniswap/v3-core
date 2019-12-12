pragma solidity 0.5.14;

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x <= y ? x : y;
    }

    function clamp112(uint y) internal pure returns (uint112 z) {
        z = y <= uint112(-1) ? uint112(y) : uint112(-1);
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            uint x = (y + 1) / 2;
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
