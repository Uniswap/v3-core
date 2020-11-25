import {Signer} from 'ethers'
import {ethers} from 'hardhat'
import {TestERC20} from '../../typechain/TestERC20'
import {TestUniswapV3Callee} from '../../typechain/TestUniswapV3Callee'
import {MockTimeUniswapV3Pair} from '../../typechain/MockTimeUniswapV3Pair'
import {TickMathTest} from '../../typechain/TickMathTest'
import {UniswapV3Factory} from '../../typechain/UniswapV3Factory'

import {expandTo18Decimals, FeeVote} from './utilities'

interface FactoryFixture {
  factory: UniswapV3Factory
}

export async function factoryFixture(feeToSetter: Signer): Promise<FactoryFixture> {
  const factoryFactory = await ethers.getContractFactory('UniswapV3Factory')
  const factory = (await factoryFactory.deploy(await feeToSetter.getAddress())) as UniswapV3Factory
  return {factory}
}

interface TokensFixture {
  token0: TestERC20
  token1: TestERC20
  token2: TestERC20
}

export async function tokensFixture(): Promise<TokensFixture> {
  const tokenFactory = await ethers.getContractFactory('TestERC20')
  const tokenA = (await tokenFactory.deploy(expandTo18Decimals(10_000))) as TestERC20
  const tokenB = (await tokenFactory.deploy(expandTo18Decimals(10_000))) as TestERC20
  const tokenC = (await tokenFactory.deploy(expandTo18Decimals(10_000))) as TestERC20

  const [token0, token1, token2] = [tokenA, tokenB, tokenC].sort((tokenA, tokenB) =>
    tokenA.address.toLowerCase() < tokenB.address.toLowerCase() ? -1 : 1
  )

  return {token0, token1, token2}
}

type TokensAndFactoryFixture = FactoryFixture & TokensFixture

interface PairFixture extends TokensAndFactoryFixture {
  pairs: {[feeVote in FeeVote]: MockTimeUniswapV3Pair}
  testCallee: TestUniswapV3Callee
  tickMath: TickMathTest
}

// Monday, October 5, 2020 9:00:00 AM GMT-05:00
export const TEST_PAIR_START_TIME = 1601906400

export async function pairFixture(feeToSetter: Signer): Promise<PairFixture> {
  const {factory} = await factoryFixture(feeToSetter)
  const {token0, token1, token2} = await tokensFixture()

  const mockTimePairFactory = await ethers.getContractFactory('MockTimeUniswapV3Pair')
  const testCalleeFactory = await ethers.getContractFactory('TestUniswapV3Callee')
  const tickMathTestFactory = await ethers.getContractFactory('TickMathTest')

  const pairs = {
    [FeeVote.FeeVote0]: (await mockTimePairFactory.deploy(
      factory.address,
      token0.address,
      token1.address,
      FeeVote.FeeVote0
    )) as MockTimeUniswapV3Pair,
    [FeeVote.FeeVote1]: (await mockTimePairFactory.deploy(
      factory.address,
      token0.address,
      token1.address,
      FeeVote.FeeVote1
    )) as MockTimeUniswapV3Pair,
    [FeeVote.FeeVote2]: (await mockTimePairFactory.deploy(
      factory.address,
      token0.address,
      token1.address,
      FeeVote.FeeVote2
    )) as MockTimeUniswapV3Pair,
    [FeeVote.FeeVote3]: (await mockTimePairFactory.deploy(
      factory.address,
      token0.address,
      token1.address,
      FeeVote.FeeVote3
    )) as MockTimeUniswapV3Pair,
    [FeeVote.FeeVote4]: (await mockTimePairFactory.deploy(
      factory.address,
      token0.address,
      token1.address,
      FeeVote.FeeVote4
    )) as MockTimeUniswapV3Pair,
    [FeeVote.FeeVote5]: (await mockTimePairFactory.deploy(
      factory.address,
      token0.address,
      token1.address,
      FeeVote.FeeVote5
    )) as MockTimeUniswapV3Pair,
  }
  for (const k in pairs) {
    await pairs[(k as any) as FeeVote].setTime(TEST_PAIR_START_TIME)
  }

  const testCallee = (await testCalleeFactory.deploy()) as TestUniswapV3Callee

  const tickMath = (await tickMathTestFactory.deploy()) as TickMathTest

  return {token0, token1, token2, pairs, factory, testCallee, tickMath}
}
