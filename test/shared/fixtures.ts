import {Contract, Signer} from 'ethers'
import {waffle} from '@nomiclabs/buidler'
const {loadFixture, deployContract} = waffle

import {expandTo18Decimals} from './utilities'

import TestERC20 from '../../build/TestERC20.json'
import UniswapV3Factory from '../../build/UniswapV3Factory.json'
import UniswapV3PairTest from '../../build/UniswapV3PairTest.json'
import MockTimeUniswapV3Pair from '../../build/MockTimeUniswapV3Pair.json'
import TestUniswapV3Callee from '../../build/TestUniswapV3Callee.json'
import TickMathTest from '../../build/TickMathTest.json'

interface FactoryFixture {
  factory: Contract
}

export async function factoryFixture([wallet]: Signer[]): Promise<FactoryFixture> {
  const factory = await deployContract(wallet, UniswapV3Factory, [await wallet.getAddress()])
  return {factory}
}

interface TokensFixture {
  token0: Contract
  token1: Contract
  token2: Contract
}

export async function tokensFixture([wallet]: Signer[]): Promise<TokensFixture> {
  const tokenA = await deployContract(wallet, TestERC20, [expandTo18Decimals(10_000)])
  const tokenB = await deployContract(wallet, TestERC20, [expandTo18Decimals(10_000)])
  const tokenC = await deployContract(wallet, TestERC20, [expandTo18Decimals(10_000)])

  const [token0, token1, token2] = [tokenA, tokenB, tokenC].sort((tokenA, tokenB) =>
    tokenA.address.toLowerCase() < tokenB.address.toLowerCase() ? -1 : 1
  )

  return {token0, token1, token2}
}

type TokensAndFactoryFixture = FactoryFixture & TokensFixture

interface PairFixture extends TokensAndFactoryFixture {
  pair: Contract
  pairTest: Contract
  testCallee: Contract
  tickMath: Contract
}

// Monday, October 5, 2020 9:00:00 AM GMT-05:00
export const TEST_PAIR_START_TIME = 1601906400

export async function pairFixture([wallet]: Signer[]): Promise<PairFixture> {
  const {factory} = await loadFixture(factoryFixture)
  const {token0, token1, token2} = await loadFixture(tokensFixture)

  const pair = await deployContract(wallet, MockTimeUniswapV3Pair, [factory.address, token0.address, token1.address])
  await pair.setTime(TEST_PAIR_START_TIME)
  const pairTest = await deployContract(wallet, UniswapV3PairTest, [pair.address])

  const testCallee = await deployContract(wallet, TestUniswapV3Callee, [])

  const tickMath = await deployContract(wallet, TickMathTest, [])

  return {token0, token1, token2, pair, pairTest, factory, testCallee, tickMath}
}
