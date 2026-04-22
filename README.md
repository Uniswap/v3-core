<img width="1284" height="689" alt="image" src="https://github.com/user-attachments/assets/1df7b169-7832-41e0-aabe-09738df1329c" /># Uniswap V3

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
## Example: Reading Pool Data

Here is a simple example using Ethers.js to read basic pool data from a Uniswap V3 pool:

```javascript
import { ethers } from "ethers";

const provider = new ethers.providers.JsonRpcProvider("YOUR_RPC_URL");

const poolAddress = "UNISWAP_POOL_ADDRESS";

const abi = [
  "function slot0() external view returns (uint160 sqrtPriceX96, int24 tick)"
];

const contract = new ethers.Contract(poolAddress, abi, provider);

async function main() {
  const data = await contract.slot0();
  console.log("sqrtPriceX96:", data.sqrtPriceX96.toString());
  console.log("tick:", data.tick);
}

main();
```
⚠️ Make sure to replace `YOUR_RPC_URL` and `UNISWAP_POOL_ADDRESS` with valid values.
## 🔄 Uniswap V3 Pool Data Flow (Simplified)

```text
+-----------------------------------------------------------+
|                    UNISWAP V3 POOL FLOW                   |
+-----------------------------------------------------------+

            👤 User / Trader
     (swap / mint / burn / collect)
                      │
                      │  on-chain call
                      ▼
        +-----------------------------------+
        |     Uniswap V3 Pool Contract      |
        |         (UniswapV3Pool.sol)       |
        +-----------------------------------+
                      │
                      ▼
        +-----------------------------------+
        |            slot0 (Core State)     |
        |   (single SLOAD, packed storage)  |
        +-----------------------------------+
           │              │              │
           ▼              ▼              ▼
   +---------------+ +---------------+ +-------------------+
   | sqrtPriceX96  | |     tick      | | observationIndex  |
   |   (Q64.96)    | | log(1.0001 P) | | oracle pointer    |
   +---------------+ +---------------+ +-------------------+
           │              │              │
           ▼              ▼              ▼
   +---------------+ +---------------+ +-------------------+
   |  Spot Price   | | Active Range  | |   TWAP / Oracle   |
   | price=(√P)^2  | | tickLower <=  | | cumulative ticks  |
   |               | | tick <= upper | | / time → avgPrice |
   +---------------+ +---------------+ +-------------------+
                      │
                      ▼
        +-----------------------------------+
        |         Derived Outputs           |
        |  • Token Price                   |
        |  • Liquidity                    |
        |  • Pool State                   |
        +-----------------------------------+
```
## Licensing

The primary license for Uniswap V3 Core is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE). However, some files are dual licensed under `GPL-2.0-or-later`:

- All files in `contracts/interfaces/` may also be licensed under `GPL-2.0-or-later` (as indicated in their SPDX headers), see [`contracts/interfaces/LICENSE`](./contracts/interfaces/LICENSE)
- Several files in `contracts/libraries/` may also be licensed under `GPL-2.0-or-later` (as indicated in their SPDX headers), see [`contracts/libraries/LICENSE`](contracts/libraries/LICENSE)

### Other Exceptions

- `contracts/libraries/FullMath.sol` is licensed under `MIT` (as indicated in its SPDX header), see [`contracts/libraries/LICENSE_MIT`](contracts/libraries/LICENSE_MIT)
- All files in `contracts/test` remain unlicensed (as indicated in their SPDX headers).
