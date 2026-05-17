1|# Uniswap V3
     2|
     3|[![Lint](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/lint.yml/badge.svg)](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/lint.yml)
     4|[![Tests](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/tests.yml/badge.svg)](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/tests.yml)
     5|[![Fuzz Testing](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/fuzz-testing.yml/badge.svg)](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/fuzz-testing.yml)
     6|[![Mythx](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/mythx.yml/badge.svg)](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/mythx.yml)
     7|[![npm version](https://img.shields.io/npm/v/@uniswap/v3-core/latest.svg)](https://www.npmjs.com/package/@uniswap/v3-core/v/latest)
     8|
     9|This repository contains the core smart contracts for the Uniswap V3 Protocol.
    10|For higher level contracts, see the [uniswap-v3-periphery](https://github.com/Uniswap/uniswap-v3-periphery)
    11|repository.
    12|
    13|## Bug bounty
    14|
    15|This repository is subject to the Uniswap V3 bug bounty program, per the terms defined [here](./bug-bounty.md).
    16|
    17|## Local deployment
    18|
    19|In order to deploy this code to a local testnet, you should install the npm package
    20|`@uniswap/v3-core`
    21|and import the factory bytecode located at
    22|`@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json`.
    23|For example:
    24|
    25|```typescript
    26|import {
    27|  abi as FACTORY_ABI,
    28|  bytecode as FACTORY_BYTECODE,
    29|} from '@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json'
    30|
    31|// deploy the bytecode
    32|```
    33|
    34|This will ensure that you are testing against the same bytecode that is deployed to
    35|mainnet and public testnets, and all Uniswap code will correctly interoperate with
    36|your local deployment.
    37|
    38|## Using solidity interfaces
    39|
    40|The Uniswap v3 interfaces are available for import into solidity smart contracts
    41|via the npm artifact `@uniswap/v3-core`, e.g.:
    42|
    43|```solidity
    44|import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
    45|
    46|contract MyContract {
    47|  IUniswapV3Pool pool;
    48|
    49|  function doSomethingWithPool() {
    50|    // pool.swap(...);
    51|  }
    52|}
    53|
    54|```
    55|
    56|## Licensing
    57|
    58|The primary license for Uniswap V3 Core is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE). However, some files are dual licensed under `GPL-2.0-or-later`:
    59|
    60|- All files in `contracts/interfaces/` may also be licensed under `GPL-2.0-or-later` (as indicated in their SPDX headers), see [`contracts/interfaces/LICENSE`](./contracts/interfaces/LICENSE)
    61|- Several files in `contracts/libraries/` may also be licensed under `GPL-2.0-or-later` (as indicated in their SPDX headers), see [`contracts/libraries/LICENSE`](contracts/libraries/LICENSE)
    62|
    63|### Other Exceptions
    64|
    65|- `contracts/libraries/FullMath.sol` is licensed under `MIT` (as indicated in its SPDX header), see [`contracts/libraries/LICENSE_MIT`](contracts/libraries/LICENSE_MIT)
    66|- All files in `contracts/test` remain unlicensed (as indicated in their SPDX headers).
    67|
## Liquidity in Uniswap V3

### What is Liquidity?

Liquidity in Uniswap refers to tokens deposited into a pool that enable trading. 
Liquidity providers (LPs) earn fees from trades that occur in their pools.

### V2 vs V3 Liquidity

| Aspect | Uniswap V2 | Uniswap V3 |
|--------|-----------|-----------|
| **Price range** | Full range (0 to ∞) | Concentrated (custom range) |
| **Capital efficiency** | Low — capital sits idle at extreme prices | High — capital focused where trades happen |
| **LP positions** | Single position per pool | Multiple positions, different ranges |
| **Fee tiers** | One per pool (0.30%) | Three tiers (0.05%, 0.30%, 1.00%) |
| **NFT representation** | ERC-20 token | ERC-721 (each position is unique) |

### Concentrated Liquidity

Uniswap V3 introduced **concentrated liquidity**, allowing LPs to provide liquidity
within a custom price range `[lowerTick, upperTick]` instead of the full range.

```
Price ────────────────────────────────────────────>
      │                                           │
      │    V2: Liquidity spread across all prices  │
      │    ████████████████████████████████████    │
      │                                           │
      │    V3: Liquidity concentrated in range     │
      │           ████████████                     │
      │         lowerTick   upperTick              │
      └───────────────────────────────────────────┘
```

### How Ticks Work

The price range is divided into **ticks** — discrete price points. Each tick is 
a price movement of 0.01% (1 basis point). LPs set their range by choosing
lower and upper tick indexes.

```
Tick spacing by fee tier:
  • 0.05% pools → tick spacing = 10 (0.1% between ticks)
  • 0.30% pools → tick spacing = 60 (0.6% between ticks)
  • 1.00% pools → tick spacing = 200 (2.0% between ticks)
```

### Virtual Liquidity

Uniswap V3 uses the formula: `L = sqrt(k)` where `k = x * y`.

For concentrated positions, the actual tokens required are calculated using:

```
x = L * (1/√P_upper - 1/√P_current)  [when P_current < P_upper]
y = L * (√P_current - √P_lower)       [when P_current > P_lower]
```

When the price exits the LP's range, their liquidity becomes inactive (only one token remains),
and they stop earning fees until the price re-enters their range.

### Active vs Inactive Liquidity

- **In range (active):** Both tokens deposited, earning fees
- **Out of range (inactive):** Only one token remaining (100% converted), no fees earned
- **100% converted:** If price moves past upper tick → all token0 → token1
  If price moves past lower tick → all token1 → token0

### Why Concentrated Liquidity Matters

1. **Higher capital efficiency** — Same fee earnings with less capital (up to 4000x)
2. **Custom strategies** — LPs can express views on where price will trade
3. **Multiple fee tiers** — Different pools for stable pairs (0.05%) vs volatile (1.00%)
4. **Active management** — LPs can adjust ranges as market conditions change

### Further Reading

- [Uniswap V3 Whitepaper](https://uniswap.org/whitepaper-v3.pdf)
- [Uniswap V3 Book](https://uniswapv3book.com/)
- [Concentrated Liquidity Deep Dive](https://docs.uniswap.org/concepts/protocol/concentrated-liquidity)
