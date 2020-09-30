import { Contract, Wallet, providers } from 'ethers'
import { deployContract } from 'ethereum-waffle'

import { expandTo18Decimals, OVERRIDES } from './utilities'

import ERC20 from '../../build/TestERC20.json'
import UniswapV3Factory from '../../build/UniswapV3Factory.json'
import UniswapV3Pair from '../../build/UniswapV3Pair.json'
import UniswapV3PairTest from '../../build/UniswapV3PairTest.json'

interface FactoryFixture {
  factory: Contract
}

export async function factoryFixture([wallet]: Wallet[]): Promise<FactoryFixture> {
  const factory = await deployContract(wallet, UniswapV3Factory, [wallet.address], OVERRIDES)
  return { factory }
}

interface PairFixture extends FactoryFixture {
  token0: Contract
  token1: Contract
  pair: Contract
  pairTest: Contract
}

export async function pairFixture([wallet]: Wallet[], provider: providers.Web3Provider): Promise<PairFixture> {
  const { factory } = await factoryFixture([wallet])

  const tokenA = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)], OVERRIDES)
  const tokenB = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)], OVERRIDES)

  await factory.createPair(tokenA.address, tokenB.address, OVERRIDES)
  const pairAddress = await factory.getPair(tokenA.address, tokenB.address)
  const pair = new Contract(pairAddress, JSON.stringify(UniswapV3Pair.abi), provider).connect(wallet)

  const token0Address = (await pair.token0()).address
  const [token0, token1] = tokenA.address === token0Address ? [tokenA, tokenB] : [tokenB, tokenA]

  const pairTest = await deployContract(wallet, UniswapV3PairTest, [pair.address], OVERRIDES)

  return { factory, token0, token1, pair, pairTest }
}
