## `UniswapV3Factory`

A factory for creating new V3 trading pairs.


Creates new pairs at deterministic addresses.


### `allPairsLength() → uint256` (external)

Gets length of allPairs array.




### `allEnabledFeeOptionsLength() → uint256` (external)

Gets length of allEnabledFeeOptions array.




### `constructor(address _owner)` (public)

The Factory contract constructor.




### `createPair(address tokenA, address tokenB, uint24 fee) → address pair` (external)

Deploys a new trading pair.




### `setOwner(address _owner)` (external)

Sets Factory contract owner to a new address.


only callable by current owner of factory contract.

### `enableFeeOption(uint24 fee)` (external)

If chosen, enables the fee option when a pair is deployed.





