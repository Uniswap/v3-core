# Uniswap v2 Smart Contracts
[![CircleCI](https://circleci.com/gh/Uniswap/uniswap-v2.svg?style=svg)](https://circleci.com/gh/Uniswap/uniswap-v2)

## Local Development

The following assumes the use of `node@^10`.

### Clone Repository
```
git clone https://github.com/Uniswap/uniswap-v2.git
cd uniswap-v2
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

### [`contracts/libraries/Math.sol`](./contracts/libraries/Math.sol)

#### OpenZeppelin
[https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2f9ae975c8bdc5c7f7fa26204896f6c717f07164/contracts/math/Math.sol#L17](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2f9ae975c8bdc5c7f7fa26204896f6c717f07164/contracts/math/Math.sol#L17)

#### dapp-bin
[https://github.com/ethereum/dapp-bin/pull/50](https://github.com/ethereum/dapp-bin/pull/50)

[https://github.com/ethereum/dapp-bin/blob/11f05fc9e3f31a00d57982bc2f65ef2654f1b569/library/math.sol#L28](https://github.com/ethereum/dapp-bin/blob/11f05fc9e3f31a00d57982bc2f65ef2654f1b569/library/math.sol#L28)

### [`contracts/libraries/SafeMath{128,256}.sol`](./contracts/libraries/)

#### OpenZeppelin
[https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2f9ae975c8bdc5c7f7fa26204896f6c717f07164/contracts/math/SafeMath.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2f9ae975c8bdc5c7f7fa26204896f6c717f07164/contracts/math/SafeMath.sol)

### [`contracts/implementations/ERC20.sol`](./contracts/implementations/ERC20.sol)

#### OpenZeppelin
[https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2f9ae975c8bdc5c7f7fa26204896f6c717f07164/contracts/token/ERC20](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/2f9ae975c8bdc5c7f7fa26204896f6c717f07164/contracts/token/ERC20)

#### Dai
[https://github.com/makerdao/dss/blob/b1fdcfc9b2ab7961bf2ce7ab4008bfcec1c73a88/src/dai.sol](https://github.com/makerdao/dss/blob/b1fdcfc9b2ab7961bf2ce7ab4008bfcec1c73a88/src/dai.sol)