## `UniswapV3Factory`

The Uniswap V3 Factory.
A factory for creating new V3 trading pairs.

Creates new pairs at deterministic addresses.

## `allPairsLength() → uint256` (external)

Gets length of allPairs array.

: length of allPairs address array.

## `allEnabledFeeOptionsLength() → uint256` (external)

Gets length of allEnabledFeeOptions array.

: of allEnabledFeeOptions array.

## `constructor(address _owner)` (public)

The Factory contract constructor.

\_owner: The owner of the Factory contract.

## `createPair(address tokenA, address tokenB, uint24 fee) → address pair` (external)

Deploys a new trading pair.

tokenA: the first token of the desired pair.

tokenB: the second token of the desired pair.

fee: the desired fee.

: Returns the address of the newly deployed pair.

## `setOwner(address _owner)` (external)

Sets Factory contract owner to a new address.

only callable by current owner of factory contract.

\_owner: The new owner of the factory contract.

## `enableFeeOption(uint24 fee)` (external)

If chosen, enables the fee option when a pair is deployed.

fee: The chosen fee option - passed via createPair.
