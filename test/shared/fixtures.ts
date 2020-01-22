import { Contract, Wallet } from 'ethers'
import { Web3Provider } from 'ethers/providers'
import { deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './utilities'

import GenericERC20 from '../../build/GenericERC20.json'
import UniswapV2Factory from '../../build/UniswapV2Factory.json'
import UniswapV2Exchange from '../../build/UniswapV2Exchange.json'

interface FactoryFixture {
  factory: Contract
}

export async function factoryFixture(_: Web3Provider, [wallet]: Wallet[]): Promise<FactoryFixture> {
  const factory = await deployContract(wallet, UniswapV2Factory, [wallet.address])
  return { factory }
}

interface ExchangeFixture extends FactoryFixture {
  token0: Contract
  token1: Contract
  exchange: Contract
}

export async function exchangeFixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<ExchangeFixture> {
  const { factory } = await factoryFixture(provider, [wallet])

  const tokenA = await deployContract(wallet, GenericERC20, [expandTo18Decimals(10000)])
  const tokenB = await deployContract(wallet, GenericERC20, [expandTo18Decimals(10000)])

  await factory.createExchange(tokenA.address, tokenB.address)
  const exchangeAddress = await factory.getExchange(tokenA.address, tokenB.address)
  const exchange = new Contract(exchangeAddress, JSON.stringify(UniswapV2Exchange.abi), provider).connect(wallet)

  const token0Address = (await exchange.token0()).address
  const token0 = tokenA.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.address === token0Address ? tokenB : tokenA

  return { factory, token0, token1, exchange }
}
