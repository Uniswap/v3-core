import { waffle, ethers } from 'hardhat'
import { BigNumber, BigNumberish, Wallet } from 'ethers'
import { MockTimeUniswapV3Pool } from '../typechain/MockTimeUniswapV3Pool'
import { UniswapV3PoolSwapTest } from '../typechain/UniswapV3PoolSwapTest'
import { TickMathTest } from '../typechain/TickMathTest'
import { expect } from './shared/expect'
import Decimal from 'decimal.js'

import { poolFixture } from './shared/fixtures'

import {
  expandTo18Decimals,
  FeeAmount,
  getMinTick,
  encodePriceSqrt,
  TICK_SPACINGS,
  createPoolFunctions,
  SwapFunction,
  MintFunction,
  getMaxTick,
  MIN_SQRT_RATIO,
  getMaxLiquidityPerTick,
  MAX_SQRT_RATIO,
  MaxUint128,
} from './shared/utilities'

const {
  constants: { MaxUint256 },
} = ethers

const createFixtureLoader = waffle.createFixtureLoader

Decimal.config({ toExpNeg: -500, toExpPos: 500 })

function priceToString(price: BigNumber): string {
  return new Decimal(price.toString()).div(new Decimal(2).pow(96)).toString()
}

describe.only('UniswapV3Pool arbitrage tests', () => {
  const [wallet, arbitrageur] = waffle.provider.getWallets()

  let loadFixture: ReturnType<typeof createFixtureLoader>

  before('create fixture loader', async () => {
    loadFixture = createFixtureLoader([wallet, arbitrageur])
  })

  for (const feeProtocol of [0, 6]) {
    describe(feeProtocol > 0 ? 'fee is on' : 'fee is off', () => {
      const startingPrice = encodePriceSqrt(1, 1)
      const startingTick = 0
      const feeAmount = FeeAmount.MEDIUM
      const tickSpacing = TICK_SPACINGS[feeAmount]
      const minTick = getMinTick(tickSpacing)
      const maxTick = getMaxTick(tickSpacing)

      const passiveLiquidity = expandTo18Decimals(100)

      const arbTestFixture = async ([wallet, arbitrageur]: Wallet[]) => {
        const fix = await poolFixture([wallet], waffle.provider)

        const pool = await fix.createPool(feeAmount, tickSpacing)

        await fix.token0.transfer(arbitrageur.address, BigNumber.from(2).pow(254))
        await fix.token1.transfer(arbitrageur.address, BigNumber.from(2).pow(254))

        const { swapExact0For1, swapToHigherPrice, swapToLowerPrice, swapExact1For0, mint } = await createPoolFunctions(
          {
            swapTarget: fix.swapTargetCallee,
            token0: fix.token0,
            token1: fix.token1,
            pool,
          }
        )

        const testerFactory = await ethers.getContractFactory('UniswapV3PoolSwapTest')
        const tester = (await testerFactory.deploy()) as UniswapV3PoolSwapTest

        const tickMathFactory = await ethers.getContractFactory('TickMathTest')
        const tickMath = (await tickMathFactory.deploy()) as TickMathTest

        await fix.token0.approve(tester.address, MaxUint256)
        await fix.token1.approve(tester.address, MaxUint256)

        await pool.initialize(startingPrice)
        if (feeProtocol != 0) await pool.setFeeProtocol(feeProtocol, feeProtocol)
        await mint(wallet.address, minTick, maxTick, passiveLiquidity)

        expect((await pool.slot0()).tick).to.eq(startingTick)
        expect((await pool.slot0()).sqrtPriceX96).to.eq(startingPrice)

        return { pool, swapExact0For1, mint, swapToHigherPrice, swapToLowerPrice, swapExact1For0, tester, tickMath }
      }

      let swapExact0For1: SwapFunction
      let swapToHigherPrice: SwapFunction
      let swapToLowerPrice: SwapFunction
      let swapExact1For0: SwapFunction
      let pool: MockTimeUniswapV3Pool
      let mint: MintFunction
      let tester: UniswapV3PoolSwapTest
      let tickMath: TickMathTest

      beforeEach('load the fixture', async () => {
        ;({
          swapExact0For1,
          pool,
          mint,
          swapToHigherPrice,
          swapToLowerPrice,
          swapExact1For0,
          tester,
          tickMath,
        } = await loadFixture(arbTestFixture))
      })

      async function simulateSwap(
        zeroForOne: boolean,
        amountSpecified: BigNumberish,
        sqrtPriceLimitX96?: BigNumber
      ): Promise<{
        executionPrice: BigNumber
        nextSqrtRatio: BigNumber
        marginalPriceEqualExecutionPrice: BigNumber
        amount0Delta: BigNumber
        amount1Delta: BigNumber
      }> {
        const { amount0Delta, amount1Delta, nextSqrtRatio } = await tester.callStatic.getSwapResult(
          pool.address,
          zeroForOne,
          amountSpecified,
          sqrtPriceLimitX96 ?? (zeroForOne ? MIN_SQRT_RATIO.add(1) : MAX_SQRT_RATIO.sub(1))
        )

        const executionPrice = zeroForOne
          ? encodePriceSqrt(amount1Delta, amount0Delta.mul(-1))
          : encodePriceSqrt(amount1Delta.mul(-1), amount0Delta)

        // this is a rough approximation, increasing/decreasing sqrt ratio by 15 bips
        const marginalPriceEqualExecutionPrice = zeroForOne
          ? executionPrice.mul(10015).div(10000)
          : executionPrice.mul(9985).div(10000)

        return { executionPrice, nextSqrtRatio, marginalPriceEqualExecutionPrice, amount0Delta, amount1Delta }
      }

      it('sandwiched swap', async () => {
        const zeroForOne = true
        const inputAmount = expandTo18Decimals(10)

        const { executionPrice, marginalPriceEqualExecutionPrice } = await simulateSwap(zeroForOne, inputAmount)

        const tickFirst =
          Math.ceil((await tickMath.getTickAtSqrtRatio(marginalPriceEqualExecutionPrice)) / tickSpacing) * tickSpacing
        const tickLast = tickFirst - tickSpacing

        const priceSwapStart = await tickMath.getSqrtRatioAtTick(tickFirst)
        // first frontrun to the first tick before the execution price
        const { amount0Delta: frontrunDelta0, amount1Delta: frontrunDelta1 } = await simulateSwap(
          true,
          MaxUint128,
          priceSwapStart
        )

        const frontrunTx = await swapToLowerPrice(priceSwapStart, arbitrageur.address)
        // deposit max liquidity at the tick
        const mintTx = await mint(wallet.address, tickLast, tickFirst, getMaxLiquidityPerTick(tickSpacing))

        const { executionPrice: executionPriceAfter } = await simulateSwap(zeroForOne, inputAmount)
        await swapExact0For1(expandTo18Decimals(1), wallet.address)

        expect({
          expectedPrice: priceToString(executionPrice),
          sandwichedPrice: priceToString(executionPriceAfter),
          frontrunDelta0: frontrunDelta0.toString(),
          frontrunDelta1: frontrunDelta1.toString(),
        }).to.matchSnapshot()
      })
    })
  }
})
