# Uniswap V3 Core

[![Lint](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/lint.yml/badge.svg)](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/lint.yml)
[![Tests](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/tests.yml/badge.svg)](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/tests.yml)
[![Fuzz Testing](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/fuzz-testing.yml/badge.svg)](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/fuzz-testing.yml)
[![Mythx](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/mythx.yml/badge.svg)](https://github.com/Uniswap/uniswap-v3-core/actions/workflows/mythx.yml)
[![npm version](https://img.shields.io/npm/v/@uniswap/v3-core/latest.svg)](https://www.npmjs.com/package/@uniswap/v3-core/v/latest)

This repository contains the core smart contracts for the Uniswap V3 Protocol. For higher-level contracts, see the [uniswap-v3-periphery](https://github.com/Uniswap/uniswap-v3-periphery) repository.

## Overview

Uniswap V3 introduced concentrated liquidity, which is a mechanism that allows liquidity providers to allocate capital within custom price ranges, enabling significantly greater capital efficiency compared to earlier AMM designs. Since its launch, V3 has processed over $2.75 trillion in trading volume without a single hack or exploit.

The core contracts in this repository implement the fundamental pool logic: creating pools, executing swaps, and managing liquidity positions. Each pool is defined by a token pair and fee tier, with liquidity concentrated within discrete price ranges (ticks).

For the latest version of the protocol, see [Uniswap v4-core](https://github.com/Uniswap/v4-core).

## Bug Bounty

This repository is subject to the Uniswap V3 bug bounty program, per the terms defined [here](./bug-bounty.md).

## Local Deployment

To deploy this code to a local testnet, you should install the npm package `@uniswap/v3-core` and import the factory bytecode located at `@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json`. For example:

```typescript
import {
  abi as FACTORY_ABI,
  bytecode as FACTORY_BYTECODE,
} from '@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json'

// deploy the bytecode
```

This will ensure that you are testing against the same bytecode that is deployed to mainnet and public testnets, and all Uniswap code will correctly interoperate with your local deployment.

## Using Solidity Interfaces

The Uniswap v3 interfaces are available for import into Solidity smart contracts via the npm artifact `@uniswap/v3-core`, e.g.:

```solidity
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

contract MyContract {
  IUniswapV3Pool pool;

  function doSomethingWithPool() {
    // pool.swap(...);
  }
}
```

## Security

This repository is subject to the Uniswap V3 bug bounty program. See [bug-bounty.md](./bug-bounty.md) for full details.

**Audits:**

| Auditor | Report |
|---------|--------|
| Trail of Bits | [audits/tob](./audits/tob) |
| ABDK | [audits/abdk](./audits/abdk) |

## Documentation

- [Uniswap V3 Documentation](https://docs.uniswap.org/contracts/v3/overview) — Full technical docs, guides, and API reference
- [v3-periphery](https://github.com/Uniswap/uniswap-v3-periphery) — Peripheral contracts for interacting with V3
- [Uniswap V3 Development Book](https://uniswapv3book.com) — Community resource for understanding V3 internals
- [Uniswap v4-core](https://github.com/Uniswap/v4-core) — Latest version of the protocol

## Community

- [Discord](https://discord.gg/uniswap) — General chat and developer support
- [Governance Forum](https://gov.uniswap.org) — Proposals and protocol discussion
- [Twitter/X](https://x.com/Uniswap) — Announcements and updates

## Licensing

The primary license for Uniswap V3 Core is the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE). However, some files are dual licensed under `GPL-2.0-or-later`:

- All files in `contracts/interfaces/` may also be licensed under `GPL-2.0-or-later` (as indicated in their SPDX headers), see [`contracts/interfaces/LICENSE`](./contracts/interfaces/LICENSE)
- Several files in `contracts/libraries/` may also be licensed under `GPL-2.0-or-later` (as indicated in their SPDX headers), see [`contracts/libraries/LICENSE`](./contracts/libraries/LICENSE)

### Other Exceptions

- `contracts/libraries/FullMath.sol` is licensed under `MIT` (as indicated in its SPDX header), see [`contracts/libraries/LICENSE_MIT`](./contracts/libraries/LICENSE_MIT)
- All files in `contracts/test` remain unlicensed (as indicated in their SPDX headers).
