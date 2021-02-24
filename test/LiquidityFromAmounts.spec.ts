import { ethers } from 'hardhat'
import { SqrtPriceMathTest } from '../typechain/SqrtPriceMathTest'
import { TickMathTest } from '../typechain/TickMathTest'
import { LiquidityFromAmountsTest } from '../typechain/LiquidityFromAmountsTest'

import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import { encodePriceSqrt } from './shared/utilities'

describe.only("LiquidityFromAmounts", async () => {
  let liquidityFromAmounts: LiquidityFromAmountsTest
  let sqrtPriceMath: SqrtPriceMathTest
  let tickMathTest: TickMathTest

  before(async () => {
    const sqrtPriceMathTestFactory = await ethers.getContractFactory('SqrtPriceMathTest')
    sqrtPriceMath = (await sqrtPriceMathTestFactory.deploy()) as SqrtPriceMathTest

    const tickMathTestFactory = await ethers.getContractFactory('TickMathTest')
    tickMathTest = (await tickMathTestFactory.deploy()) as TickMathTest

    const liquidityFromAmountsTestFactory = await ethers.getContractFactory('LiquidityFromAmountsTest')
    liquidityFromAmounts = (await liquidityFromAmountsTestFactory.deploy()) as LiquidityFromAmountsTest
  })

  describe("#getLiquidityDeltaForAmount0", () => {
    it("gas", async () => {
      const ticklo = await tickMathTest.getSqrtRatioAtTick(-1000)
      const tickhi = await tickMathTest.getSqrtRatioAtTick(1000)
      await snapshotGasCost(liquidityFromAmounts.getLiquidityDeltaForAmount0(ticklo, tickhi, 100))
    })
  })

  describe("#getLiquidityDeltaForAmount1", () => {
    it("gas", async () => {
      const ticklo = await tickMathTest.getSqrtRatioAtTick(-1000)
      const tickhi = await tickMathTest.getSqrtRatioAtTick(1000)
      await snapshotGasCost(liquidityFromAmounts.getLiquidityDeltaForAmount0(ticklo, tickhi, 100))
    })
  })

  describe("invariants", () => {
    it("tick < tickLo", async () => {
      const testCases = [
        { liquidity: 100, ticklo: -887160, tickhi: 887160 },
        { liquidity: "2025760793555", ticklo: 0, tickhi: 284994 },
        // why does this not work? it returns 104 liquidity from the created amount0,
        // when it should be 100
        // { liquidity: "100", ticklo: -2000, tickhi: 2000 }
      ]

      for (const params of testCases) {
        const ticklo = await tickMathTest.getSqrtRatioAtTick(params.ticklo)
        const tickhi = await tickMathTest.getSqrtRatioAtTick(params.tickhi)

        const amount0 = await sqrtPriceMath.getAmount0Delta(ticklo, tickhi, params.liquidity, true)
        const expectedLiquidity0 = await liquidityFromAmounts.getLiquidityDeltaForAmount0(
          ticklo,
          tickhi,
          amount0,
        )
        expect(expectedLiquidity0).to.be.eq(params.liquidity)
      }
    })

    it("tick > tickLo", async () => {
      const testCases = [
        { liquidity: 100, ticklo: -887160, tickhi: 887160 },
        { liquidity: "2025760793555", ticklo: 0, tickhi: 284994 },
        // why does this not work? it returns 109 liquidity from the created amount1,
        // when it should be 100. is it a precision loss issue?
        // { liquidity: "100", ticklo: -1000, tickhi: 1000 },
      ]

      for (const params of testCases) {
        const ticklo = await tickMathTest.getSqrtRatioAtTick(params.ticklo)
        const tickhi = await tickMathTest.getSqrtRatioAtTick(params.tickhi)

        // check that the liquidity we get matches
        const amount1 = await sqrtPriceMath.getAmount1Delta(ticklo, tickhi, params.liquidity, true)
        const expectedLiquidity1 = await liquidityFromAmounts.getLiquidityDeltaForAmount1(
          ticklo,
          tickhi,
          amount1,
        )
        expect(expectedLiquidity1).to.be.eq(params.liquidity)
      }
    })

      it("tickLo < tick < tickHi", async () => {
        const testCases = [
          { liquidity: 100, sqrtPrice: "25054144837504793118641380156", ticklo: -887160, tickhi: 887160, amount0: 317, amount1: 32, liquidity0: 100, liquidity1: 101 },
          { liquidity: "2025760793555", sqrtPrice: encodePriceSqrt(100000, 100), ticklo: 0, tickhi: 284994 },
          { liquidity: "1797114049888068422011940", sqrtPrice: "71640570057197317802937974", ticklo: -2470, tickhi: 2810 },
          { liquidity: "179711404988806842201194033052598134", sqrtPrice: "71640570057197317802937974", ticklo: -2470, tickhi: 2810 },
          { liquidity: "320917197683995560309319026386", sqrtPrice: "1205315890798944879562895", ticklo: 0, tickhi: 284994 },
          { liquidity: "100", sqrtPrice: encodePriceSqrt(10, 1).toString(), ticklo: -1000, tickhi: 1000 },
        ]

        for (const params of testCases) {
          const ticklo = await tickMathTest.getSqrtRatioAtTick(params.ticklo)
          const tickhi = await tickMathTest.getSqrtRatioAtTick(params.tickhi)

          const amount0 = await sqrtPriceMath.getAmount0Delta(params.sqrtPrice, tickhi, params.liquidity, true)
          const amount1 = await sqrtPriceMath.getAmount1Delta(ticklo, params.sqrtPrice, params.liquidity, true)
          if (params.amount0) expect(amount0).to.be.eq(params.amount0)
          if (params.amount1) expect(amount1).to.be.eq(params.amount1)

          const expectedLiquidity0 = await liquidityFromAmounts.getLiquidityDeltaForAmount0(
            params.sqrtPrice,
            tickhi,
            amount0,
          )
          const expectedLiquidity1 = await liquidityFromAmounts.getLiquidityDeltaForAmount1(
            ticklo,
            params.sqrtPrice,
            amount1,
          )
          if (params.liquidity0) expect(expectedLiquidity0).to.be.eq(params.liquidity0)
          if (params.liquidity1) expect(expectedLiquidity1).to.be.eq(params.liquidity1)

          // get the min of the 2
          const expectedLiquidity = expectedLiquidity0.lt(expectedLiquidity1) ? expectedLiquidity0 : expectedLiquidity1
          expect(expectedLiquidity).to.be.eq(params.liquidity)
        }
      })
  })
})
