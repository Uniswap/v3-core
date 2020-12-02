## `IUniswapV3Factory`






### `owner() → address` (external)





### `allPairs(uint256) → address pair` (external)

Gets the address of a given pair contract.


Pass the uint representing the pair address in the allPairs array.


### `allPairsLength() → uint256` (external)

Gets length of the allPairs array.




### `allEnabledFeeOptions(uint256) → uint24` (external)





### `allEnabledFeeOptionsLength() → uint256` (external)

Gets length of allEnabledFeeOptions array.




### `getPair(address tokenA, address tokenB, uint24 fee) → address pair` (external)

Gets the address of a trading pair.




### `isFeeOptionEnabled(uint24 fee) → bool` (external)





### `createPair(address tokenA, address tokenB, uint24 fee) → address pair` (external)

Deploys a new trading pair.




### `setOwner(address)` (external)

Sets Factory contract owner to a new address.



### `enableFeeOption(uint24 fee)` (external)

If chosen, enables the fee option when a pair is deployed.





### `OwnerChanged(address oldOwner, address newOwner)`





### `PairCreated(address token0, address token1, uint24 fee, address pair, uint256)`





### `FeeOptionEnabled(uint24 fee)`





