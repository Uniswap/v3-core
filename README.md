# Uniswap V3

[![Lint](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/lint.yml/badge.svg)](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/lint.yml)
[![Tests](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/tests.yml/badge.svg)](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/tests.yml)
[![Fuzz Testing](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/fuzz-testing.yml/badge.svg)](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/fuzz-testing.yml)
[![Mythx](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/mythx.yml/badge.svg)](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/mythx.yml)
[![npm version](https://img.shields.io/npm/v/@uniswap/v3-core/latest.svg)](https://www.npmjs.com/package/@uniswap/v3-core/v/latest)

This repository contains the core smart contracts for the Uniswap V3 Protocol.
For higher level contracts, see the [uniswap-v3-periphery](https://github.com/Uniswap/uniswap-v3-periphery)
repository.

## Bug bounty

This repository is subject to the Uniswap V3 bug bounty program, per the terms defined [here](./bug-bounty.md).

## Local deployment

In order to deploy this code to a local testnet, you should install the npm package
`@uniswap/v3-core`
and import the factory bytecode located at
`@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json`.
For example:

```typescript
import {
  abi as FACTORY_ABI,
  bytecode as FACTORY_BYTECODE,
} from '@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json'

// deploy the bytecode
```

This will ensure that you are testing against the same bytecode that is deployed to
mainnet and public testnets, and all Uniswap code will correctly interoperate with
your local deployment.

## Using solidity interfaces

The Uniswap v3 interfaces are available for import into solidity smart contracts
via the npm artifact `@uniswap/v3-core`, e.g.:

```solidity
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

contract MyContract {
  IUniswapV3Pool pool;

  function doSomethingWithPool() {
    // pool.swap(...);
  }
}

```
### Understanding Pool Data (Beginner Friendly - Detailed)

When interacting with a Uniswap V3 pool, some important values are returned that may be confusing for beginners. These values are packed inside a structure called `slot0`, which is designed for gas optimization and efficient state access.

#### What is slot0?

`slot0` is a struct that stores multiple frequently used variables of the pool in a single storage slot. This reduces gas costs and improves performance when reading pool state.

It contains:

- **sqrtPriceX96**  
  This represents the current price of the pool in a fixed-point format (Q64.96).  
  It is not a direct price. To get the actual token price, it must be converted using mathematical formulas.  
  This format allows very high precision in price calculations.

- **tick**  
  The tick represents the current price index of the pool.  
  Each tick corresponds to a specific price range.  
  Instead of storing price directly, Uniswap uses ticks to efficiently manage liquidity across ranges.

- **observationIndex**  
  Points to the latest stored observation in the oracle array.

- **observationCardinality**  
  Total number of observations currently stored.

- **observationCardinalityNext**  
  The next maximum number of observations to be stored (used for oracle expansion).

- **feeProtocol**  
  Represents the protocol fee as a percentage of swap fees.

- **unlocked**  
  A boolean value indicating whether the pool is currently locked or not (used to prevent reentrancy issues).

#### Why is slot0 important?

Understanding `slot0` is essential because:

- It gives the **current state of the pool**
- It is used in **price calculation**
- It plays a key role in **swaps and liquidity logic**
- It helps developers understand how Uniswap V3 manages **efficient storage and gas optimization**

Adding a clear understanding of these values helps new developers work with Uniswap V3 more effectively.
## Licensing

The primary license for Uniswap V3 Core is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE). However, some files are dual licensed under `GPL-2.0-or-later`:

- All files in `contracts/interfaces/` may also be licensed under `GPL-2.0-or-later` (as indicated in their SPDX headers), see [`contracts/interfaces/LICENSE`](./contracts/interfaces/LICENSE)
- Several files in `contracts/libraries/` may also be licensed under `GPL-2.0-or-later` (as indicated in their SPDX headers), see [`contracts/libraries/LICENSE`](contracts/libraries/LICENSE)

### Other Exceptions

- `contracts/libraries/FullMath.sol` is licensed under `MIT` (as indicated in its SPDX header), see [`contracts/libraries/LICENSE_MIT`](contracts/libraries/LICENSE_MIT)
- All files in `contracts/test` remain unlicensed (as indicated in their SPDX headers).
