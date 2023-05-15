import type { NetworkUserConfig } from 'hardhat/types'
import 'hardhat-typechain'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-etherscan'

require('dotenv').config()

const COMPILER_SETTINGS = {
  version: '0.7.6',
  settings: {
    evmVersion: 'istanbul',
    optimizer: {
      enabled: true,
      runs: 800,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const SPECIFIC_COMPILER_SETTINGS = {
  version: '0.7.6',
  settings: {
    evmVersion: 'istanbul',
    optimizer: {
      enabled: true,
      runs: 800,
    },
    metadata: {
      bytecodeHash: 'none',
    },
  },
}

const local: NetworkUserConfig = {
  url: 'http://127.0.0.1:8545/',
  chainId: 1337,
  accounts: [process.env.ACCOUNT_KEY_LOCAL!],
  allowUnlimitedContractSize: true
}

const testnet: NetworkUserConfig = {
  url: 'https://data-seed-prebsc-2-s1.binance.org:8545/',
  chainId: 97,
  accounts: [process.env.ACCOUNT_KEY_TESTNET!],
  allowUnlimitedContractSize: true
}

const mainnet: NetworkUserConfig = {
  url: 'https://bsc-dataseed.binance.org/',
  chainId: 56,
  accounts: [process.env.ACCOUNT_KEY_MAINNET!],
  allowUnlimitedContractSize: true
}

export default {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    ...(process.env.ACCOUNT_KEY_LOCAL && { local }),
    ...(process.env.ACCOUNT_KEY_TESTNET && { testnet }),
    ...(process.env.ACCOUNT_KEY_MAINNET && { mainnet })
  },
  etherscan: {
    apiKey: process.env.API_KEY,
  },
  solidity: {
    compilers: [COMPILER_SETTINGS],
    overrides: {
      'contracts/LeChainPool.sol': SPECIFIC_COMPILER_SETTINGS,
      'contracts/LeChainFactory.sol': SPECIFIC_COMPILER_SETTINGS,
      'contracts/test/MockTimeLeChainPool.sol': SPECIFIC_COMPILER_SETTINGS,
      'contracts/test/MockTimeLeChainPoolDeployer.sol': SPECIFIC_COMPILER_SETTINGS
    }
  },
  mocha: {
    timeout: 50000,
  },
}
