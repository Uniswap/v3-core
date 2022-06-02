import { Wallet } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { MockTimeUniswapV3Pool } from '../typechain/MockTimeUniswapV3Pool'
import { SimulateTest } from '../typechain/SimulateTest'
import { TestERC20 } from '../typechain/TestERC20'
import { TestUniswapV3Callee } from '../typechain/TestUniswapV3Callee'
import { expect } from './shared/expect'
import { poolFixture } from './shared/fixtures'
import {
  createPoolFunctions,
  encodePriceSqrt,
  expandTo18Decimals,
  FeeAmount,
  getMaxTick,
  getMinTick,
  MAX_SQRT_RATIO,
  MintFunction,
  MIN_SQRT_RATIO,
  SwapFunction,
  TICK_SPACINGS,
} from './shared/utilities'

const createFixtureLoader = waffle.createFixtureLoader

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T

describe('Simulate', () => {
  let wallet: Wallet, other: Wallet

  let token0: TestERC20
  let token1: TestERC20

  let pool: MockTimeUniswapV3Pool

  let swapTarget: TestUniswapV3Callee
  let simulate: SimulateTest

  let swapExact0For1: SwapFunction
  let swapExact1For0: SwapFunction

  let feeAmount: number
  let tickSpacing: number

  let minTick: number
  let maxTick: number

  let mint: MintFunction

  let loadFixture: ReturnType<typeof createFixtureLoader>
  let createPool: ThenArg<ReturnType<typeof poolFixture>>['createPool']

  before('create fixture loader', async () => {
    ;[wallet, other] = await (ethers as any).getSigners()
    loadFixture = createFixtureLoader([wallet, other])
  })

  beforeEach('deploy fixture', async () => {
    ;({ token0, token1, createPool, swapTargetCallee: swapTarget } = await loadFixture(poolFixture))

    simulate = (await (await ethers.getContractFactory('SimulateTest')).deploy()) as SimulateTest

    const oldCreatePool = createPool
    createPool = async (_feeAmount, _tickSpacing) => {
      const pool = await oldCreatePool(_feeAmount, _tickSpacing)
      ;({ swapExact0For1, swapExact1For0, mint } = createPoolFunctions({
        token0,
        token1,
        swapTarget,
        pool,
      }))
      minTick = getMinTick(_tickSpacing)
      maxTick = getMaxTick(_tickSpacing)
      feeAmount = _feeAmount
      tickSpacing = _tickSpacing
      return pool
    }

    // default to the 30 bips pool
    pool = await createPool(FeeAmount.MEDIUM, TICK_SPACINGS[FeeAmount.MEDIUM])
  })

  describe('#simulateSwap', () => {
    beforeEach('initialize the pool at price of 1:1', async () => {
      await pool.initialize(encodePriceSqrt(1, 1))
      await mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))
    })

    it('initial balances', async () => {
      expect(await token0.balanceOf(pool.address)).to.eq(expandTo18Decimals(1))
      expect(await token1.balanceOf(pool.address)).to.eq(expandTo18Decimals(1))
    })

    it('zeroForOne = true', async () => {
      const amountIn = 1000

      const { amount0, amount1 } = await simulate.simulateSwap(pool.address, true, amountIn, MIN_SQRT_RATIO.add(1))
      expect(amount0).to.eq(amountIn)
      expect(amount1).to.eq(-996)

      await expect(swapExact0For1(amountIn, wallet.address))
        .to.emit(pool, 'Swap')
        .withArgs(
          swapTarget.address,
          wallet.address,
          amountIn,
          -996,
          '79228162514264258603065923615',
          expandTo18Decimals(1),
          -1
        )
    })

    it('zeroForOne = false', async () => {
      const amountIn = 1000

      const { amount0, amount1 } = await simulate.simulateSwap(pool.address, false, amountIn, MAX_SQRT_RATIO.sub(1))
      expect(amount0).to.eq(-996)
      expect(amount1).to.eq(amountIn)

      await expect(swapExact1For0(amountIn, wallet.address))
        .to.emit(pool, 'Swap')
        .withArgs(
          swapTarget.address,
          wallet.address,
          -996,
          amountIn,
          '79228162514264416584021977057',
          expandTo18Decimals(1),
          0
        )
    })
  })
})
