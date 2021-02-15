import Decimal from 'decimal.js'
import { BigNumber, BigNumberish, Wallet } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { MockTimeUniswapV3Pool } from '../typechain/MockTimeUniswapV3Pool'
import { TickMathTest } from '../typechain/TickMathTest'
import { UniswapV3PoolSwapTest } from '../typechain/UniswapV3PoolSwapTest'
import { expect } from './shared/expect'

import { poolFixture } from './shared/fixtures'

import {
  createPoolFunctions,
  encodePriceSqrt,
  expandTo18Decimals,
  FeeAmount,
  getMaxLiquidityPerTick,
  getMaxTick,
  getMinTick,
  MAX_SQRT_RATIO,
  MaxUint128,
  MIN_SQRT_RATIO,
  MintFunction,
  SwapFunction,
  TICK_SPACINGS,
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

  for (const feeProtocol of [/*0,*/ 6]) {
    describe(`swap protocol fee = ${feeProtocol};`, () => {
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

        return { executionPrice, nextSqrtRatio, amount0Delta, amount1Delta }
      }

      function increaseRatio(sqrtRatio: BigNumber, byPips: number): BigNumber {
        return BigNumber.from(
          new Decimal(
            sqrtRatio
              .mul(sqrtRatio)
              .mul(1e6 + byPips)
              .div(1e6)
              .toString()
          )
            .sqrt()
            .floor()
            .toString()
        )
      }

      describe('exact input of 10e18 token0', async () => {
        const zeroForOne = true
        const inputAmount = expandTo18Decimals(10)

        it('not sandwiched swap', async () => {
          const { executionPrice, amount1Delta, amount0Delta } = await simulateSwap(zeroForOne, inputAmount)
          await swapExact0For1(inputAmount, wallet.address)

          expect({
            executionPrice: priceToString(executionPrice),
            amount0Delta: amount0Delta.toString(),
            amount1Delta: amount1Delta.toString(),
            priceAfter: priceToString((await pool.slot0()).sqrtPriceX96),
          }).to.matchSnapshot()
        })

        it('sandwiched with swap to execution price then mint max liquidity/burn max liquidity', async () => {
          const { executionPrice } = await simulateSwap(zeroForOne, inputAmount)

          const firstTickAboveMarginalPrice =
            Math.ceil((await tickMath.getTickAtSqrtRatio(increaseRatio(executionPrice, feeAmount))) / tickSpacing) *
            tickSpacing
          const tickAfterFirstTickAboveMarginPrice = firstTickAboveMarginalPrice - tickSpacing

          const priceSwapStart = await tickMath.getSqrtRatioAtTick(firstTickAboveMarginalPrice)

          let arbBalance0 = BigNumber.from(0)
          let arbBalance1 = BigNumber.from(0)

          // first frontrun to the first tick before the execution price
          const {
            amount0Delta: frontrunDelta0,
            amount1Delta: frontrunDelta1,
            executionPrice: frontrunExecutionPrice,
          } = await simulateSwap(true, MaxUint256.div(2), priceSwapStart)
          arbBalance0 = arbBalance0.sub(frontrunDelta0)
          arbBalance1 = arbBalance1.sub(frontrunDelta1)
          await swapToLowerPrice(priceSwapStart, arbitrageur.address)

          // deposit max liquidity at the tick
          const mintReceipt = await (
            await mint(
              wallet.address,
              tickAfterFirstTickAboveMarginPrice,
              firstTickAboveMarginalPrice,
              getMaxLiquidityPerTick(tickSpacing)
            )
          ).wait()
          // sub the mint costs
          const { amount0: amount0Mint, amount1: amount1Mint } = pool.interface.decodeEventLog(
            pool.interface.events['Mint(address,address,int24,int24,uint128,uint256,uint256)'],
            mintReceipt.events?.[2].data!
          )
          arbBalance0 = arbBalance0.sub(amount0Mint)
          arbBalance1 = arbBalance1.sub(amount1Mint)

          // execute the user's swap
          const { executionPrice: executionPriceAfterFrontrun } = await simulateSwap(zeroForOne, inputAmount)
          await swapExact0For1(inputAmount, wallet.address)

          // burn the arb's liquidity
          const burnReceipt = await (
            await pool.burn(
              wallet.address,
              tickAfterFirstTickAboveMarginPrice,
              firstTickAboveMarginalPrice,
              getMaxLiquidityPerTick(tickSpacing)
            )
          ).wait()
          // add the burn returns
          const { amount0: amount0Burn, amount1: amount1Burn } = pool.interface.decodeEventLog(
            pool.interface.events['Burn(address,address,int24,int24,uint128,uint256,uint256)'],
            burnReceipt.events?.[2].data!
          )
          arbBalance0 = arbBalance0.add(amount0Burn)
          arbBalance1 = arbBalance1.add(amount1Burn)

          // add the fees as well
          const { amount0: amount0Collect, amount1: amount1Collect } = await pool.callStatic.collect(
            arbitrageur.address,
            tickAfterFirstTickAboveMarginPrice,
            firstTickAboveMarginalPrice,
            MaxUint128,
            MaxUint128
          )
          arbBalance0 = arbBalance0.add(amount0Collect)
          arbBalance1 = arbBalance1.add(amount1Collect)

          // swap to be net neutral
          const {
            amount0Delta: backrunDelta0,
            amount1Delta: backrunDelta1,
            executionPrice: backrunExecutionPrice,
          } = arbBalance1.lt(0)
            ? await simulateSwap(false, arbBalance1.mul(-1))
            : await simulateSwap(true, arbBalance0.mul(-1))
          arbBalance0 = arbBalance0.sub(backrunDelta0)
          arbBalance1 = arbBalance1.sub(backrunDelta1)

          expect({
            sandwichedPrice: priceToString(executionPriceAfterFrontrun),
            arbBalanceDelta0: arbBalance0.toString(),
            arbBalanceDelta1: arbBalance1.toString(),
            backrun: {
              executionPrice: priceToString(backrunExecutionPrice),
              delta0: backrunDelta0.toString(),
              delta1: backrunDelta1.toString(),
            },
            frontrun: {
              executionPrice: priceToString(frontrunExecutionPrice),
              delta0: frontrunDelta0.toString(),
              delta1: frontrunDelta1.toString(),
            },
            collect: {
              amount0: amount0Collect.toString(),
              amount1: amount1Collect.toString(),
            },
            burn: {
              amount0: amount0Burn.toString(),
              amount1: amount1Burn.toString(),
            },
            mint: {
              amount0: amount0Mint.toString(),
              amount1: amount1Mint.toString(),
            },
            finalPrice: priceToString((await pool.slot0()).sqrtPriceX96),
          }).to.matchSnapshot()
        })
      })
    })
  }
})
