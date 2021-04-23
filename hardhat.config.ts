import 'hardhat-typechain'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-etherscan'
import '@eth-optimism/hardhat-ovm'
import 'hardhat-contract-sizer'

import { BigNumber, providers, Wallet } from 'ethers'
import { MockProvider } from 'ethereum-waffle'

import { extendEnvironment } from 'hardhat/config'
extendEnvironment((hre) => {
  if (hre.network.name == 'optimism') {
    // Override Waffle Fixtures to be no-ops, because l2geth does not support
    // snapshotting
    // @ts-ignore
    hre.waffle.loadFixture = async (fixture: Promise<any>) => await fixture()
    hre.waffle.createFixtureLoader = (wallets: Wallet[] | undefined, provider: MockProvider | undefined) => {
      return async function load(fixture: any) {
        return await fixture()
      }
    }

    // Temporarily set gasPrice = 0, until l2geth provides pre-funded l2 accounts.
    const provider = new providers.JsonRpcProvider('http://localhost:8545')
    provider.pollingInterval = 100
    provider.getGasPrice = async () => BigNumber.from(0)
    hre.ethers.provider = provider

    // hre.waffle.provider.getWallets() throws if network.name !== 'hardhat', so we override it to generate 20
    // wallets using Hardhat's default mnemonic and derivation path
    hre.waffle.provider.getWallets = () => {
      const mnemonic = 'test test test test test test test test test test test junk'
      const path = "m/44'/60'/0'/0"
      const indices = Array.from(Array(20).keys()) // generates array of [0, 1, 2, ..., 18, 19]
      return indices.map((i) => hre.ethers.Wallet.fromMnemonic(mnemonic, `${path}/${i}`).connect(provider))
    }
  }
})

export default {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    optimism: {
      url: 'http://localhost:8545',
      ovm: true,
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  solidity: {
    version: '0.7.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1,
      },
      metadata: {
        // do not include the metadata hash, since this is machine dependent
        // and we want all generated code to be deterministic
        // https://docs.soliditylang.org/en/v0.7.6/metadata.html
        bytecodeHash: 'none',
      },
    },
  },
}
