# LeChain Protocol

[![npm version](https://img.shields.io/npm/v/@lechainnetwork/lcp-core/latest.svg)](https://www.npmjs.com/package/@lechainnetwork/lcp-core/v/latest)

This repository contains the core smart contracts for the LeChain Protocol.
For higher level contracts, see the [lcp-periphery](https://github.com/lechainnetwork/lcp-periphery)
repository.

## Local deployment

In order to deploy this code to a local testnet, you should install the npm package
`@lechainnetwork/lcp-core`
and import the factory bytecode located at
`@lechainnetwork/lcp-core/artifacts/contracts/LeChainFactory.sol/LeChainFactory.json`.
For example:

```typescript
import {
  abi as FACTORY_ABI,
  bytecode as FACTORY_BYTECODE,
} from '@lechainnetwork/lcp-core/artifacts/contracts/LeChainFactory.sol/LeChainFactory.json'

// deploy the bytecode
```

This will ensure that you are testing against the same bytecode that is deployed to
mainnet and public testnets, and all Uniswap code will correctly interoperate with
your local deployment.

## Using solidity interfaces

The LeChain Protocol interfaces are available for import into solidity smart contracts
via the npm artifact `@lechainnetwork/lcp-core`, e.g.:

```solidity
import '@lechainnetwork/lcp-core/contracts/interfaces/ILeChainPool.sol';

contract MyContract {
  ILeChainPool pool;

  function doSomethingWithPool() {
    // pool.swap(...);
  }
}

```

## Licensing

The primary license for LeChain Core Protocol is the GNU General Public License v3.0 (`GPL-3.0-or-later`), see [`LICENSE`](./LICENSE).

### Other Exceptions

- `contracts/libraries/FullMath.sol` is licensed under `MIT` (as indicated in its SPDX header), see [`contracts/libraries/LICENSE_MIT`](contracts/libraries/LICENSE_MIT)
- All files in `contracts/test` remain unlicensed (as indicated in their SPDX headers).