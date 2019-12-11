# Uniswap v2 Smart Contracts
[![CircleCI](https://circleci.com/gh/Uniswap/uniswap-v2-core.svg?style=svg)](https://circleci.com/gh/Uniswap/uniswap-v2-core)

## Local Development

The following assumes the use of `node@^10`.

### Clone Repository
```
git clone https://github.com/Uniswap/uniswap-v2-core.git
cd uniswap-v2-core
```

### Install Dependencies
```
yarn
```

### Compile Contracts and Run Tests
```
yarn compile
yarn test
```


## Implementation References

- [dapphub math](https://github.com/dapphub/ds-math/blob/de4576712dcf2c5152d16a04e677002d51d46e60/src/math.sol)
- [dapp-bin math](https://github.com/ethereum/dapp-bin/pull/50)
- [OpenZeppelin ECDSA](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/81b1e4810761b088922dbd19a0642873ea581176/contracts/cryptography/ECDSA.sol)
- [OpenZeppelin SafeERC20](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/81b1e4810761b088922dbd19a0642873ea581176/contracts/token/ERC20/SafeERC20.sol)
- [DAI token](https://github.com/makerdao/dss/blob/17be7db1c663d8069308c6b78fa5c5f9d71134a3/src/dai.sol)
