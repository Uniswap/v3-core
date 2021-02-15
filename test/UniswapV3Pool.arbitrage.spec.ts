import { waffle, ethers } from 'hardhat'
import { BigNumber, Wallet } from 'ethers'
import { MockTimeUniswapV3Pool } from '../typechain/MockTimeUniswapV3Pool'
import { UniswapV3PoolSwapTest } from '../typechain/UniswapV3PoolSwapTest'
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
  const [wallet] = waffle.provider.getWallets()

  let loadFixture: ReturnType<typeof createFixtureLoader>

  before('create fixture loader', async () => {
    loadFixture = createFixtureLoader([wallet])
  })

  for (const feeProtocol of [0, 6]) {
    describe(feeProtocol > 0 ? 'fee is on' : 'fee is off', () => {
      const startingPrice = encodePriceSqrt(100001, 100000)
      const startingTick = 0
      const feeAmount = FeeAmount.MEDIUM
      const tickSpacing = TICK_SPACINGS[feeAmount]
      const minTick = getMinTick(tickSpacing)
      const maxTick = getMaxTick(tickSpacing)

      const passiveLiquidity = expandTo18Decimals(100)

      const arbTestFixture = async ([wallet]: Wallet[]) => {
        const fix = await poolFixture([wallet], waffle.provider)

        const pool = await fix.createPool(feeAmount, tickSpacing)

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
        await fix.token0.approve(tester.address, MaxUint256)
        await fix.token1.approve(tester.address, MaxUint256)

        await pool.initialize(startingPrice)
        if (feeProtocol != 0) await pool.setFeeProtocol(feeProtocol, feeProtocol)
        await mint(wallet.address, minTick, maxTick, passiveLiquidity)

        expect((await pool.slot0()).tick).to.eq(startingTick)
        expect((await pool.slot0()).sqrtPriceX96).to.eq(startingPrice)

        return { pool, swapExact0For1, mint, swapToHigherPrice, swapToLowerPrice, swapExact1For0, tester }
      }

      let swapExact0For1: SwapFunction
      let swapToHigherPrice: SwapFunction
      let swapToLowerPrice: SwapFunction
      let swapExact1For0: SwapFunction
      let pool: MockTimeUniswapV3Pool
      let mint: MintFunction
      let tester: UniswapV3PoolSwapTest

      beforeEach('load the fixture', async () => {
        ;({
          swapExact0For1,
          pool,
          mint,
          swapToHigherPrice,
          swapToLowerPrice,
          swapExact1For0,
          tester,
        } = await loadFixture(arbTestFixture))
      })

      it('sandwiched swap', async () => {
        const { amount0Delta, amount1Delta } = await tester.callStatic.getSwapResult(
          pool.address,
          true,
          expandTo18Decimals(1),
          MIN_SQRT_RATIO.add(1)
        )

        const executionPrice = encodePriceSqrt(amount1Delta, amount0Delta.mul(-1))

        expect(priceToString(executionPrice)).to.matchSnapshot()
      })
    })
  }
})
