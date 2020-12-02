## `UniswapV3Pair`

The V3 pair allows for liquidity provisioning within user specified positions and swapping between two assets.


Liquidity positions are partitioned into "ticks", each tick is equally spaced and may have arbitrary depth of liquidity providing the token has a total supply of < 2**128.

### `lock()`






### `isInitialized() → bool` (public)

Check for one-time initialization.




### `constructor(address _factory, address _token0, address _token1, uint24 _fee)` (public)

The Pair constructor.


Executed only once when a pair is initialized.


### `_blockTimestamp() → uint32` (internal)

Overridden for tests.




### `setFeeTo(address feeTo_)` (external)

Sets the destination where the swap fees are routed to.


only able to be called by "feeToSetter".

### `initialize(int24 tick)` (external)

Initializes a new pair.




### `setPosition(int24 tickLower, int24 tickUpper, int128 liquidityDelta) → int256 amount0, int256 amount1` (external)

Sets the position of a given liquidity provision.




### `swap0For1(uint256 amount0In, address to, bytes data) → uint256 amount1Out` (external)

The first main swap function.
Used when moving from right to left (token 1 is becoming more valuable).




### `swap1For0(uint256 amount1In, address to, bytes data) → uint256 amount0Out` (external)

The second main swap function.
Used when moving from left to right (token 0 is becoming more valuable).




### `recover(address token, address to, uint256 amount)` (external)

Allows factory contract owner to recover tokens, other than token0 and token1, accidentally sent to the pair contract.





