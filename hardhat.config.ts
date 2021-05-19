import 'hardhat-typechain'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-etherscan'
import '@eth-optimism/hardhat-ovm'
import 'hardhat-contract-sizer'

import { BigNumber, Contract, Wallet, Signer } from 'ethers'
import { Deferrable } from '@ethersproject/properties'
import { JsonRpcProvider, TransactionRequest, TransactionResponse } from '@ethersproject/providers'
import { MockProvider } from 'ethereum-waffle'
import { extendEnvironment } from 'hardhat/config'
import { FactoryOptions } from '@nomiclabs/hardhat-ethers/src/types/index'

// Helper classes and methods for testing against l2geth are defined here. Typically when testing against Ganache or
// Hardhat, transaction are mined instantly so these is not required. But when testing against l2geth transactions are
// not mined instantly, so we need to explicitly call `.wait()` after all transactions, including contract deployments
// and contract calls. To avoid needing to modify the test suite, we define helper classes and methods that are used
// to override the default behavior of certain methods, so `.wait()` is always called automatically. The
// `makeContractWait` and `deployWaitingContract` methods are based on code from https://github.com/ethereum-optimism/optimism/blob/52d9e6b73362a203bdae3fa0182bd6e7c9693b13/packages/contracts/src/hardhat-deploy-ethers.ts#L107-L129

/**
 * @notice Extends the Wallet class so signers always wait for transactions to be mined
 */
class WaitWallet extends Wallet {
  sendTransaction(transaction: Deferrable<TransactionRequest>): Promise<TransactionResponse> {
    return this.sendTransaction(transaction).then((tx) => {
      return this.provider.waitForTransaction(tx.hash).then((receipt) => {
        return tx
      })
    })
  }
}

/**
 * @notice Takes a contract and modifies all functions to automatically `.wait()` on calls, and returns the new contract
 * @param contract Contract to modify
 */
function makeContractWait(contract: Contract) {
  for (const fnName of Object.keys(contract.functions)) {
    const fn = contract[fnName].bind(contract)
    ;(contract as any)[fnName] = async (...args: any) => {
      const result = await fn(...args)
      if (typeof result === 'object' && typeof result.wait === 'function') {
        await result.wait()
      }
      return result
    }
  }
  return contract
}

/**
 * @notice Deploys a contract, then modifies the contract so method calls always .wait(), and returns that contract
 * with the specified signer attached to it
 * @dev This is similar to createWaitingContract, but is an asynchronous version for contract deployments
 * @param deployBound The deployer method, bound to the appropriate `this` context
 * @param deployArgs Contract deployment arguments
 * @param wallet Wallet to attach to the deployed contract
 */
async function deployWaitingContract(
  deployBound: (...args: any[]) => Promise<Contract>,
  deployArgs: any[],
  wallet: Wallet
) {
  // Temporarily override Object.defineProperty to bypass ether's object protection.
  // We override Object.defineProperty because ethers uses it to make certain properties read-only. Contract functions
  // are one of these things that ethers tries to make read-only. We need to disable this so we can override the
  // function to add that automatic `.wait()` but there's no way to make a property writable once it's already
  // been marked as `writable: false`. It seems like there are cases in which `prop.writable = true` is disallowed
  // when other properties are attached to `prop`, so if we only use `prop.writable = true` we'd get the following
  // error:
  //   `TypeError: Invalid property descriptor. Cannot both specify accessors and a value or writable attribute, #<Object>`
  // So the trick here is to assume that the ethers codebase probably uses Object.defineProperty correctly, and
  // therefore likely explicitly sets `prop.writable = false` whenever they'd like to make something read-only. If
  // `prop.writable = false` then those other attributes definitely can't be attached to prop or else they'd get the
  // exact same error as the one above. So adding a check that `prop.writable === false` before setting
  // `prop.writable = true` is safe
  //   -- From Kelvin
  const def = Object.defineProperty
  Object.defineProperty = (obj, propName, prop) => {
    if (prop.writable === false) {
      prop.writable = true
    }
    return def(obj, propName, prop)
  }

  // Wait for deploy
  let contract = await deployBound(...deployArgs)
  await contract.deployTransaction.wait()
  contract = contract.connect(wallet)

  // Now reset Object.defineProperty
  Object.defineProperty = def

  // Return a contract that waits on calls
  return makeContractWait(contract)
}

/**
 * @notice Creates a contract, the modifies the contract so method calls always .wait(), and returns that contract
 * with the specified signer attached to it
 * @dev This is similar to deployWaitingContract, but is a synchronous version for new contract instances, not deployments
 * @param createFunction A method that when called with creationArgs creates a new contract instance
 * @param createArgs Arguments to pass to the createFunction
 * @param wallet Wallet to attach to the deployed contract
 */
function createWaitingContract(createFunction: (...args: any[]) => Contract, createArgs: any[], wallet?: Wallet) {
  // Temporarily override Object.defineProperty to bypass ether's object protection.
  const def = Object.defineProperty
  Object.defineProperty = (obj, propName, prop) => {
    // See comments in `deployWaitingContract()` for explanation of this block
    if (prop.writable === false) {
      prop.writable = true
    }
    return def(obj, propName, prop)
  }

  // Create contract
  let contract = createFunction(...createArgs)
  if (wallet) contract.connect(wallet)

  // Now reset Object.defineProperty
  Object.defineProperty = def

  // Return a contract that waits on calls
  return makeContractWait(contract)
}

extendEnvironment((hre) => {
  if (hre.network.name == 'optimism') {
    // Override Waffle Fixtures to be no-ops, because l2geth does not support snapshotting
    // @ts-expect-error
    hre.waffle.loadFixture = async (fixture: Promise<any>) => await fixture()
    hre.waffle.createFixtureLoader = (wallets: Wallet[] | undefined, provider: MockProvider | undefined) => {
      return async function load(fixture: any) {
        return await fixture(wallets, provider)
      }
    }

    // Temporarily set gasPrice = 0, until l2geth provides pre-funded l2 accounts.
    const provider = new JsonRpcProvider('http://localhost:8545')
    provider.pollingInterval = 100
    provider.getGasPrice = async () => BigNumber.from(0)
    hre.ethers.provider = provider

    // hre.waffle.provider.getWallets() throws if network.name !== 'hardhat', so we override it to generate 20
    // wallets using Hardhat's default mnemonic and derivation path
    hre.waffle.provider.getWallets = () => {
      const mnemonic = 'test test test test test test test test test test test junk'
      const path = "m/44'/60'/0'/0"
      const indices = Array.from(Array(20).keys()) // generates array of [0, 1, 2, ..., 18, 19]
      return indices.map((i) => WaitWallet.fromMnemonic(mnemonic, `${path}/${i}`).connect(provider))
    }

    // Define the default signer we want to use for all transactions
    const defaultWallet = hre.waffle.provider.getWallets()[0]

    // Save off the current definition of getContractFactory and modify implementation to always call `.wait()`
    const getContractFactory = hre.ethers.getContractFactory

    // @ts-expect-error: getContractFactory has two different function signatures but here we only use one
    hre.ethers.getContractFactory = async function (name: string, signerOrOptions?: Signer | FactoryOptions) {
      // First get the nominal factory instance
      const factory = await getContractFactory(name, signerOrOptions)

      // Modify the `.connect()` method so the contract it returns has the default signer attached
      const connect = factory.connect
      factory.connect = function (signer: Signer) {
        // Bind the `.connect()` method to the ContractFactory and get the default factory instance
        const newFactory = connect.bind(this)(signer)

        // Modify factory's `.deploy()` method to return a contract with the default signer that always calls `.wait()`
        const deploy = newFactory.deploy
        newFactory.deploy = async function (...args: any[]) {
          return await deployWaitingContract(deploy.bind(this), args, defaultWallet)
        }

        // Modify factory's `.attach()` method to return a contract with the default signer that always calls `.wait()`
        const attach = newFactory.attach
        newFactory.attach = function (address: string) {
          const createFunction = attach.bind(this)
          const contract = createWaitingContract(createFunction, [address], defaultWallet)

          // Modify the new contract's `.connect()` to return a new contract that always calls `.wait()`
          const connect = contract.connect
          contract.connect = function (signer: Signer) {
            const createFunction = connect.bind(this)
            return createWaitingContract(createFunction, [signer]) // no signer here, since it's provided as an argument
          }
          return contract
        }
        return newFactory
      }

      // Modify factory's `.deploy()` method to return a contract with the default signer that always calls `.wait()`.
      // This is the same as what's done a few lines above, but for the *factory's* `deploy()` method, whereas the
      // one above is for the `deploy()` method of the factory returned from `factory.connect()`
      const deploy = factory.deploy
      factory.deploy = async function (...args: any[]) {
        return await deployWaitingContract(deploy.bind(this), args, defaultWallet)
      }

      // Connect our default wallet to the factory and return it
      return factory.connect(defaultWallet)
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
  mocha: {
    timeout: 180000,
  },
}
