import { Wallet } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { TestERC20 } from '../typechain/TestERC20'
import { UniswapV3Factory } from '../typechain/UniswapV3Factory'
import { MockTimeUniswapV3Pool } from '../typechain/MockTimeUniswapV3Pool'
import { expect } from './shared/expect'

import { poolFixture } from './shared/fixtures'

import {
  FeeAmount,
  TICK_SPACINGS,
  createPoolFunctions,
  PoolFunctions,
  createMultiPoolFunctions,
  encodePriceSqrt,
  getMinTick,
  getMaxTick,
  expandTo18Decimals,
} from './shared/utilities'
import { TestUniswapV3Router } from '../typechain/TestUniswapV3Router'
import { TestUniswapV3Callee } from '../typechain/TestUniswapV3Callee'

const feeAmount = FeeAmount.MEDIUM
const tickSpacing = TICK_SPACINGS[feeAmount]

const createFixtureLoader = waffle.createFixtureLoader

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T

describe('UniswapV3Pool', () => {
  let wallet: Wallet, other: Wallet

  let token0: TestERC20
  let token1: TestERC20
  let token2: TestERC20
  let factory: UniswapV3Factory
  let pool0: MockTimeUniswapV3Pool
  let pool1: MockTimeUniswapV3Pool

  let pool0Functions: PoolFunctions
  let pool1Functions: PoolFunctions

  let minTick: number
  let maxTick: number

  let swapTargetCallee: TestUniswapV3Callee
  let swapTargetRouter: TestUniswapV3Router

  let loadFixture: ReturnType<typeof createFixtureLoader>
  let createPool: ThenArg<ReturnType<typeof poolFixture>>['createPool']

  before('create fixture loader', async () => {
    ;[wallet, other] = await (ethers as any).getSigners()

    loadFixture = createFixtureLoader([wallet, other])
  })

  beforeEach('deploy first fixture', async () => {
    ;({ token0, token1, token2, factory, createPool, swapTargetCallee, swapTargetRouter } = await loadFixture(
      poolFixture
    ))

    const createPoolWrapped = async (
      amount: number,
      spacing: number,
      firstToken: TestERC20,
      secondToken: TestERC20
    ): Promise<[MockTimeUniswapV3Pool, any]> => {
      const pool = await createPool(amount, spacing, firstToken, secondToken)
      const poolFunctions = createPoolFunctions({
        swapTarget: swapTargetCallee,
        token0: firstToken,
        token1: secondToken,
        pool,
      })
      minTick = getMinTick(spacing)
      maxTick = getMaxTick(spacing)
      return [pool, poolFunctions]
    }

    // default to the 30 bips pool
    ;[pool0, pool0Functions] = await createPoolWrapped(feeAmount, tickSpacing, token0, token1)
    ;[pool1, pool1Functions] = await createPoolWrapped(feeAmount, tickSpacing, token1, token2)
  })

  it('constructor initializes immutables', async () => {
    expect(await pool0.factory()).to.eq(factory.address)
    expect(await pool0.token0()).to.eq(token0.address)
    expect(await pool0.token1()).to.eq(token1.address)
    expect(await pool1.factory()).to.eq(factory.address)
    expect(await pool1.token0()).to.eq(token1.address)
    expect(await pool1.token1()).to.eq(token2.address)
  })

  describe('multi-swaps', () => {
    let inputToken: TestERC20
    let outputToken: TestERC20

    beforeEach('initialize both pools', async () => {
      inputToken = token0
      outputToken = token2

      await pool0.initialize(encodePriceSqrt(1, 1))
      await pool1.initialize(encodePriceSqrt(1, 1))

      await pool0Functions.mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))
      await pool1Functions.mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))
    })

    it('multi-swap', async () => {
      const token0OfPoolOutput = await pool1.token0()
      const ForExact0 = outputToken.address === token0OfPoolOutput

      const { swapForExact0Multi, swapForExact1Multi } = createMultiPoolFunctions({
        inputToken: token0,
        swapTarget: swapTargetRouter,
        poolInput: pool0,
        poolOutput: pool1,
      })

      const method = ForExact0 ? swapForExact0Multi : swapForExact1Multi

      await expect(method(100, wallet.address))
        .to.emit(outputToken, 'Transfer')
        .withArgs(pool1.address, wallet.address, 100)
        .to.emit(token1, 'Transfer')
        .withArgs(pool0.address, pool1.address, 102)
        .to.emit(inputToken, 'Transfer')
        .withArgs(wallet.address, pool0.address, 104)
    })
  })
})
