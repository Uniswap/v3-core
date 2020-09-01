// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.6.11;
pragma experimental ABIEncoderV2;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';
import '../UniswapV3Pair.sol';

interface IERC20 {
    function mint(address to, uint amount) external;
}

contract SameBlockTest is UniswapV3Pair {
    constructor(address token0, address token1) public UniswapV3Pair(token0, token1) { }
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

    // Ensures that the `fee` is fixed across the whole block and is set before any trade is executed
    function testFeeConstantInsideABlock(uint16 requiredFee) public {
        uint16 feeBefore = feeCurrent;

        IERC20(token0).mint(msg.sender, 100000e18);
        IERC20(token1).mint(msg.sender, 100000e18);

        // the first call will set the fee to the fee based on the last trade's reserves
        require(requiredFee != 20000, "provide a different fee vote from the one you're supplying");
        setPosition(-4, 4, FeeVote.FeeVote5, 10000e18);
        require(feeCurrent == requiredFee, "feeCurrent != provided fee");

        // adding more liquidity or executing a trade in the same block does not alter the feeCurrent
        setPosition(-4, 4, FeeVote.FeeVote5, 1000e18);
        require(feeCurrent == requiredFee, "feeCurrent changed");

        // executing a trade in the same block does not alter the feeCurrent
        swap0For1(3e18, msg.sender, '');
        require(feeCurrent == requiredFee, "feeCurrent changed");
    }
}

