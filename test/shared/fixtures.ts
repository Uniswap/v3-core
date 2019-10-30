import { providers, Wallet, Contract } from 'ethers'
import { deployContract } from 'ethereum-waffle'

import { CHAIN_ID } from './constants'
import { expandTo18Decimals } from './utilities'

import ERC20 from '../../build/GenericERC20.json'
import UniswapV2 from '../../build/UniswapV2.json'
import UniswapV2Factory from '../../build/UniswapV2Factory.json'

export interface FactoryFixture {
  bytecode: string
  factory: Contract
}

export async function factoryFixture(provider: providers.Web3Provider, [wallet]: Wallet[]): Promise<FactoryFixture> {
  const bytecode = `0x${UniswapV2.evm.bytecode.object}`
  const factory = await deployContract(wallet, UniswapV2Factory, [bytecode, CHAIN_ID], {
    gasLimit: (provider._web3Provider as any).options.gasLimit
  })

  return { bytecode, factory }
}

export interface ExchangeFixture extends FactoryFixture {
  token0: Contract
  token1: Contract
  exchange: Contract
}

export async function exchangeFixture(provider: providers.Web3Provider, [wallet]: Wallet[]): Promise<ExchangeFixture> {
  const { bytecode, factory } = await factoryFixture(provider, [wallet])

  const tokenA = await deployContract(wallet, ERC20, ['Mock Token A', 'MOCKA', 18, expandTo18Decimals(1000), CHAIN_ID])
  const tokenB = await deployContract(wallet, ERC20, ['Mock Token B', 'MOCKB', 18, expandTo18Decimals(1000), CHAIN_ID])

  await factory.createExchange(tokenA.address, tokenB.address)
  const exchangeAddress = await factory.getExchange(tokenA.address, tokenB.address)
  const exchange = new Contract(exchangeAddress, JSON.stringify(UniswapV2.abi), provider)

  const [token0Address] = await factory.getTokens(exchangeAddress)
  const token0 = tokenA.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.address === token0Address ? tokenB : tokenA

  return { bytecode, factory, token0, token1, exchange }
}
