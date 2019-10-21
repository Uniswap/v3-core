pragma solidity ^0.5.11;

library Math {

  function min(uint256 a, uint256 b) internal pure returns (uint256) {
      return a < b ? a : b;
  }

  // based on https://github.com/ethereum/dapp-bin/pull/50/files#diff-2f78bfcc90b711a5c3bb69fd5b04f11aR28
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
