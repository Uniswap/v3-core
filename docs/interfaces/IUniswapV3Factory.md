## `IUniswapV3Factory`






## `owner() → address` (external)

Gets the owner address of the factory contract.





: the owner address.

## `allPairs(uint256) → address pair` (external)

Gets the address of a given pair contract.


Pass the uint representing the pair address in the allPairs array.



: Returns the pair address.

## `allPairsLength() → uint256` (external)

Gets length of the allPairs array.





: of allPairs address array.

## `allEnabledFeeOptions(uint256) → uint24` (external)







## `allEnabledFeeOptionsLength() → uint256` (external)

Gets length of allEnabledFeeOptions array.





: of allEnabledFeeOptions array.

## `getPair(address tokenA, address tokenB, uint24 fee) → address pair` (external)

Gets the address of a trading pair.




tokenA: The first token of the pair.

tokenB: The second token of the pair.

fee: The fee of the pair.


: Returns address of the pair given the previous arguments.

## `isFeeOptionEnabled(uint24 fee) → bool` (external)







## `createPair(address tokenA, address tokenB, uint24 fee) → address pair` (external)

Deploys a new trading pair.




tokenA: the first token of the desired pair.

tokenB: the second token of the desired pair.

fee: the desired fee.


: Returns the address of the newly deployed pair.

## `setOwner(address)` (external)

Sets Factory contract owner to a new address.





## `enableFeeOption(uint24 fee)` (external)

If chosen, enables the fee option when a pair is deployed.




fee: The chosen fee option - passed via createPair.



## `OwnerChanged(address oldOwner, address newOwner)`





## `PairCreated(address token0, address token1, uint24 fee, address pair, uint256)`





## `FeeOptionEnabled(uint24 fee)`





