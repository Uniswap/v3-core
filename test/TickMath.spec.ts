import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import { TickMathTest } from '../typechain/TickMathTest'
import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import { encodePriceSqrt } from './shared/utilities'

const MIN_TICK = -887272
const MAX_TICK = 887272

const MIN_SQRT_RATIO = BigNumber.from('4295128739')
const MAX_SQRT_RATIO = BigNumber.from('1461446703485210103287273052203988822378723970342')

describe('TickMath', () => {
  let tickMath: TickMathTest

  before('deploy TickMathTest', async () => {
    const factory = await ethers.getContractFactory('TickMathTest')
    tickMath = (await factory.deploy()) as TickMathTest
  })

  describe('#getSqrtRatioAtTick', () => {
    it('throws for too low', async () => {
      await expect(tickMath.getSqrtRatioAtTick(MIN_TICK - 1)).to.be.revertedWith('T')
    })

    it('throws for too low', async () => {
      await expect(tickMath.getSqrtRatioAtTick(MAX_TICK + 1)).to.be.revertedWith('T')
    })

    it('min tick', async () => {
      expect(await tickMath.getSqrtRatioAtTick(MIN_TICK)).to.eq('4295128739')
    })

    it('min tick +1', async () => {
      expect(await tickMath.getSqrtRatioAtTick(MIN_TICK + 1)).to.eq('4295343490')
    })

    it('max tick - 1', async () => {
      expect(await tickMath.getSqrtRatioAtTick(MAX_TICK - 1)).to.eq('1461373636630004318706518188784493106690254656249')
    })

    it('min tick ratio is less than js implementation', async () => {
      expect(await tickMath.getSqrtRatioAtTick(MIN_TICK)).to.be.lt(encodePriceSqrt(1, BigNumber.from(2).pow(127)))
    })

    it('max tick ratio is greater than js implementation', async () => {
      expect(await tickMath.getSqrtRatioAtTick(MAX_TICK)).to.be.gt(encodePriceSqrt(BigNumber.from(2).pow(127), 1))
    })

    it('max tick', async () => {
      expect(await tickMath.getSqrtRatioAtTick(MAX_TICK)).to.eq('1461446703485210103287273052203988822378723970342')
    })

    for (const absTick of [
      50,
      100,
      250,
      500,
      1_000,
      2_500,
      3_000,
      4_000,
      5_000,
      50_000,
      150_000,
      250_000,
      500_000,
      738_203,
    ]) {
      for (const tick of [-absTick, absTick]) {
        describe(`tick ${tick}`, () => {
          it('result', async () => {
            expect((await tickMath.getSqrtRatioAtTick(tick)).toString()).to.matchSnapshot()
          })
          it('gas', async () => {
            await snapshotGasCost(tickMath.getGasCostOfGetSqrtRatioAtTick(tick))
          })
        })
      }
    }
  })

  describe('#MIN_SQRT_RATIO', async () => {
    it('equals #getSqrtRatioAtTick(MIN_TICK)', async () => {
      const min = await tickMath.getSqrtRatioAtTick(MIN_TICK)
      expect(min).to.eq(await tickMath.MIN_SQRT_RATIO())
      expect(min).to.eq(MIN_SQRT_RATIO)
    })
  })

  describe('#MAX_SQRT_RATIO', async () => {
    it('equals #getSqrtRatioAtTick(MAX_TICK)', async () => {
      const max = await tickMath.getSqrtRatioAtTick(MAX_TICK)
      expect(max).to.eq(await tickMath.MAX_SQRT_RATIO())
      expect(max).to.eq(MAX_SQRT_RATIO)
    })
  })

  describe('#getTickAtSqrtRatio', () => {
    it('throws for too low', async () => {
      await expect(tickMath.getTickAtSqrtRatio(MIN_SQRT_RATIO.sub(1))).to.be.revertedWith('R')
    })

    it('throws for too high', async () => {
      await expect(tickMath.getTickAtSqrtRatio(BigNumber.from(MAX_SQRT_RATIO))).to.be.revertedWith('R')
    })

    it('ratio of min tick', async () => {
      expect(await tickMath.getTickAtSqrtRatio(MIN_SQRT_RATIO)).to.eq(MIN_TICK)
    })
    it('ratio of min tick + 1', async () => {
      expect(await tickMath.getTickAtSqrtRatio('4295343490')).to.eq(MIN_TICK + 1)
    })
    it('ratio of max tick - 1', async () => {
      expect(await tickMath.getTickAtSqrtRatio('1461373636630004318706518188784493106690254656249')).to.eq(MAX_TICK - 1)
    })
    it('ratio closest to max tick', async () => {
      expect(await tickMath.getTickAtSqrtRatio(MAX_SQRT_RATIO.sub(1))).to.eq(MAX_TICK - 1)
    })

    for (const ratio of [MIN_SQRT_RATIO, MAX_SQRT_RATIO.sub(1)]) {
      describe(`ratio ${ratio}`, () => {
        it('result', async () => {
          expect((await tickMath.getTickAtSqrtRatio(ratio)).toString()).to.matchSnapshot()
        })
        it('gas', async () => {
          await snapshotGasCost(tickMath.getGasCostOfGetTickAtSqrtRatio(ratio))
        })
      })
    }
  })
})
