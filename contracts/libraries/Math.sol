pragma solidity 0.5.12;

library Math {
    function add512(uint x0, uint64 x1, uint y0, uint64 y1) internal pure returns (uint z0, uint64 z1) {
        assembly {
            z0 := add(x0, y0)
            z1 := add(add(x1, y1), lt(z0, x0))
        }
    }
    function mul512(uint x, uint64 y) internal pure returns (uint z0, uint64 z1) {
        assembly {
            let mm := mulmod(x, y, not(0))
            z0 := mul(x, y)
            z1 := sub(sub(mm, z0), lt(mm, z0))
        }
    }

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
