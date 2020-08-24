// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.11;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '../UniswapV3Pair.sol';

contract CumulativePriceTest is UniswapV3Pair {
    constructor() public UniswapV3Pair(address(0), address(0)) { }
    // Ensures that `update` can get called multiple times
    // in a block without messing the value of the 
    // `price{0,1}CumulativeLast variables
    function testUpdateMultipleTransactionsSameBlock() public {
        // Initialize the values properly
        price0CumulativeLast = FixedPoint.uq144x112(0);
        price1CumulativeLast = FixedPoint.uq144x112(0);
        blockTimestampLast = uint32(block.timestamp - 100);
        reserve0Virtual = 100;
        reserve1Virtual = 200;


        // The first call will set the prices
        super._update();
        FixedPoint.uq144x112 memory price0Snapshot = price0CumulativeLast;
        FixedPoint.uq144x112 memory price1Snapshot = price1CumulativeLast;
        require(price0Snapshot._x != 0, "price0 should change on the 1st call to update");
        require(price1Snapshot._x != 0, "price1 should change on the 1st call to update");

        // It should be idempotent in further calls
        super._update();
        require(price0CumulativeLast._x == price0Snapshot._x, "price0 should not change after 2nd call to update");
        require(price1CumulativeLast._x == price1Snapshot._x, "price1 should not change after 2nd call to update");
    }
}

