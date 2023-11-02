# Uniswap V3 with Limit Orders

This repo was forked from UniswapV3 in order to add an additional feature to the core pool, limit orders. Currently, users can simulate limit orders by providing liquidity to a tick interval that is above or below the current tick.  
Since, the ticks are not the active ones, they provide just one token as liquidity, and when the price reaches this tick, the tokens are swapped to the opposite one, i.e., `token0` is swapped by `token1` when the limit order tick is greater than the current tick, and `token1` is swapped by `token0` when it's less than the current tick.  
One problem is, users need to be aware of when the swap takes place, or the price trend can revert and all swapped tokens will be reverted to the previous one.  
To tackle this issue, the `UniswapV3 Core` contracts were forked and two new functions were added to it, `createLimitOrder`, which allows the user to create limit orders and `collectLimitOrder`, which allows the users to collect the swapped tokens or cancel their orders.

## Changes

### Lines
1. `103-122`: Additional Variables;
2. `514-580`: `createLimitOrder` function;
3. `582-620`: `_removeUserLiquidityWithFees` helper function;
4. `622-686`: `collectLimitOrder` function;
5. `954-987`: Limit order liquidation loop.

### Added Functions:
1. `createLimitOrder`: Places a limit order at a given [`tickLower`, `tickLower + tickSpacing`) interval.
```
function createLimitOrder(address recipient, int24 tickLower, uint128 amount) external;
```

2. `collectLimitOrder`: Claims limit orders placed at a given [`tickLower`, `tickLower + tickSpacing`) interval. If it has been liquidated, claims swapped tokens, if not, return the provided liquidity.
```
function collectLimitOrder(address recipient, int24 tickLower) external;
```

### Additional variables
1. `currentLimitEpoch`: Used to keep track of the current limit order epoch.
```
// tickLower => epoch
mapping(int24 => uint256) public currentLimitEpoch;
```

2. `userEpochInfos`: Used to store variables that auxiliate creating and claiming limit orders.
```
struct UserEpochInfo {
    uint256 currIndex;
    uint256 epochLength;
    uint256 lastAddedEpoch;
}
// (tickLower, user) => UserEpochInfo
mapping(bytes32 => UserEpochInfo) public userEpochInfos;
```

3. `userEpochs`: Array containing which epochs the user participated, used to avoid looping through epochs that were already claimed buy the user in `collectLimitOrder` function.
```
/// (tickLower, user) => User Epochs
mapping(bytes32 => uint256[]) public userEpochs;
```

4. `limitOrderStatuses`: Variables containing the status/metadata for each limit order instance. Such as the way it's going to be liquidated (`zeroForOne`), if any limit order was already placed for this tick and epoch (`initialized`), the total liquidity provided (`totalLiquidity`) and how much of the order was filled (`totalFilled`).
```
struct LimitOrderStatus {
    bool initialized;
    bool zeroForOne;
    uint128 totalFilled;
    uint128 totalLiquidity;
}
/// (tickLower, epoch) => Status of limit orders (Metadata for limit orders)
mapping(bytes32 => LimitOrderStatus) public limitOrderStatuses;
```

5. `usersLimitLiquidity`: How much each user has provided of liquidity for each of the `tickLower` and `epoch`. It's used to calculate the user share of the liquidated limit orders when claiming.
```
  /// (tickLower, epoch) => User limit liquidity 
  mapping(bytes32 => uint128) public usersLimitLiquidity;
```

### Tests
Test can be found [here](./test/UniswapV3Pool.limit.spec.ts). (UniswapV3Pool.limit.spec.ts file)

`TODO: Create more test cases to get 100% coverage`

## Rationale
When an user creates a limit order, internally, it creates a liquidity position with **DEAD** address as the owner. Such design was chosen to eliminate the necessity of looping over all limit orders when someone is doing a swap which crosses the upper bound of the limit order interval.  
When a swapped is performed, which crosses the limit order upper bound (`tickUpper`), all the limit order instances that were crossed are liquidated (liquidity from `DEAD` address removed) and the swapped tokens and fees are accounted to `totalFilled` variable.  
When the limit orders users claim their swapped tokens, they claim an amount proportional to the amount of liquidity they provided for each of the limit orders.

## Partial Fills
Partial fills are currently not implemented, since the UniswapV3 architecture does not immediately suport it.  
One of the reasons is that, when a partial liquidity position is liquidated inside the liquidity interval it were assigned to, a proportion of both `token0` and `token1` will be withdrawn, not only the token being liquidated. Even if, another liquidity position is after the operation, the same amount of both tokens will need to be provided back, influenced by the current price (constant product formula).  
One way this problem might be tackled, although it would be probably be better to rethink the architecture itself, is to create orders that might not be included in the positions liquidity pool and liquidate it when the price crosses the assigned `lowerTick`. One problem with this approach, that's solvable, is the need to determine the logic of which liquidity is going to be used first, or which proportion of both it will be used, note that, if a liquidity position is not created for the limit order tick, the limit order won't be executed until someone do so. 
