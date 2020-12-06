## `IUniswapV3Pair`






## `factory() → address` (external)

Gets the address of the factory contract.


This variable is immutable.



## `token0() → address` (external)

Gets the address of token0.


This variable is immutable.



## `token1() → address` (external)

Gets the address of token1.


This variable is immutable.



## `fee() → uint24` (external)

Gets the fee for the given pair.


This variable is immutable.



## `feeTo() → address` (external)



Gets the destination address of the pair fees.



## `blockTimestampLast() → uint32` (external)



Gets the last time since the oracle price accumulator updated.



## `liquidityCurrent() → uint128` (external)



Gets current amount of liquidity of a given pair.



## `tickBitMap(uint256) → uint256` (external)



Gets the tick bit map



## `tickCurrent() → int24` (external)



Gets the current tick of the pair.



## `priceCurrent() → uint256` (external)



Gets the current price of the pair.



## `feeGrowthGlobal0() → uint256` (external)



Gets the current fee growth global of token 0. Note this is not enough to calculated fees due. This number is part of the calculation process to find how many fees are due, per liquidity provision, in a given tick.



## `feeGrowthGlobal1() → uint256` (external)



Gets the current fee growth global of token 1. Note this is not enough to calculated fees due. This number is part of the calculation process to find how many fees are due, per liquidity provision, in a given tick.



## `feeToFees0() → uint256` (external)



Gets the accumulated protocol fees of token 0.



## `feeToFees1() → uint256` (external)



Gets the accumulated protocol fees of token 1.



## `isInitialized() → bool` (external)

Check for one-time initialization.





: determining if there is already a price, thus already an initialized pair.

## `initialize(int24 tick)` (external)

Initializes a new pair.




tick: The nearest tick to the estimated price, given the ratio of token0 / token1.


## `setPosition(int24 tickLower, int24 tickUpper, int128 liquidityDelta) → int256 amount0, int256 amount1` (external)

Sets the position of a given liquidity provision.




tickLower: The lower boundary of the position.

tickUpper: The upper boundary of the position.

liquidityDelta: The liquidity delta. (TODO what is it).


: The amount of the first token.

: The amount of the second token.

## `swap0For1(uint256 amount0In, address to, bytes data) → uint256 amount1Out` (external)

The first main swap function.
Used when moving from right to left (token 1 is becoming more valuable).




amount0In: Amount of token you are sending.

to: The destination address of the tokens.

data: The call data of the swap.


## `swap1For0(uint256 amount1In, address to, bytes data) → uint256 amount0Out` (external)

The second main swap function.
Used when moving from left to right (token 0 is becoming more valuable).




amount1In: amount of token you are sending.

to: The destination address of the tokens.

data: The call data of the swap.


## `setFeeTo(address)` (external)







## `recover(address token, address to, uint256 amount)` (external)

Allows factory contract owner to recover tokens, other than token0 and token1, accidentally sent to the pair contract.




token: The token address.

to: The destination address of the transfer.

amount: The amount of the token to be recovered.



## `Initialized(int24 tick)`





