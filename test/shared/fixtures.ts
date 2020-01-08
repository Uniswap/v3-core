import { providers, Wallet, Contract } from 'ethers'
import { deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './utilities'

import ERC20 from '../../build/ERC20.json'
import UniswapV2 from '../../build/UniswapV2.json'
import UniswapV2Factory from '../../build/UniswapV2Factory.json'

export interface FactoryFixture {
  factory: Contract
}

export async function factoryFixture(provider: providers.Web3Provider, [wallet]: Wallet[]): Promise<FactoryFixture> {
  const factory = await deployContract(wallet, UniswapV2Factory, [wallet.address])

  return { factory }
}

export interface ExchangeFixture extends FactoryFixture {
  token0: Contract
  token1: Contract
  exchange: Contract
}

export async function exchangeFixture(provider: providers.Web3Provider, [wallet]: Wallet[]): Promise<ExchangeFixture> {
  const { factory } = await factoryFixture(provider, [wallet])

  const tokenA = await deployContract(wallet, ERC20, ['Test Token A', 'TESTA', 18, expandTo18Decimals(10000)])
  const tokenB = await deployContract(wallet, ERC20, ['Test Token B', 'TESTB', 18, expandTo18Decimals(10000)])

  await factory.createExchange(tokenA.address, tokenB.address)
  const exchangeAddress = await factory.getExchange(tokenA.address, tokenB.address)
  const exchange = new Contract(exchangeAddress, JSON.stringify(UniswapV2.abi), provider)

  const token0Address = (await exchange.token0()).address
  const token0 = tokenA.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.address === token0Address ? tokenB : tokenA

  return { factory, token0, token1, exchange }
}
