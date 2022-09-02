import Decimal from 'decimal.js'
import {TickMathTest__WC__TickMathTest_compiled} from '../typechain-types'
import {expect} from 'chai';
import { getStarknetContractFactory } from 'hardhat-warp/dist/testing'
import BN from 'bn.js'
import { BigNumber, BigNumberish} from 'ethers'
import bn from 'bignumber.js'

const MIN_TICK = -887272
const MAX_TICK = 887272
export const MIN_SQRT_RATIO = BigNumber.from('4295128739')
export const MAX_SQRT_RATIO = BigNumber.from('1461446703485210103287273052203988822378723970342')

bn.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 })

// returns the sqrt price as a 64x96
export function encodePriceSqrt(reserve1: BigNumberish, reserve0: BigNumberish): BigNumber {
  return BigNumber.from(
    new bn(reserve1.toString())
      .div(reserve0.toString())
      .sqrt()
      .multipliedBy(new bn(2).pow(96))
      .integerValue(3)
      .toString()
  )
}

Decimal.config({ toExpNeg: -500, toExpPos: 500 })

describe('TickMath', () => {
  let tickMath: TickMathTest__WC__TickMathTest_compiled;

  beforeEach('deploy TickMathTest', async () => {
    const tickMathFactory = getStarknetContractFactory('TickMathTest')
    const contract = await tickMathFactory.deploy()
    tickMath = await (contract.deployed()) as TickMathTest__WC__TickMathTest_compiled
  })

  describe('#getSqrtRatioAtTick', () => {
    /*
    it('throws for too low', async () => {
      await expect(tickMath.getSqrtRatioAtTick_986cfba3(MIN_TICK - 1)).to.be.revertedWith('T')
    })

    it('throws for too low', async () => {
      await expect(tickMath.getSqrtRatioAtTick_986cfba3(MAX_TICK + 1)).to.be.revertedWith('T')
    })
    */
    it('min tick', async () => {
      const res = await tickMath.getSqrtRatioAtTick_986cfba3(new BN(MIN_TICK).toTwos(24).toString());
      expect(res[0].toNumber()).to.eq(4295128739)
    })

    it('min tick +1', async () => {
      const res = await tickMath.getSqrtRatioAtTick_986cfba3(new BN(MIN_TICK + 1).toTwos(24).toString());
      expect(res[0].toNumber()).to.eq(4295343490)
    })

    it('max tick - 1', async () => {
      const res = await tickMath.getSqrtRatioAtTick_986cfba3(new BN(MAX_TICK - 1).toString());
      expect(res[0].toString()).to.eq("1461373636630004318706518188784493106690254656249")
    })

    it('min tick ratio is less than js implementation', async () => {
      const res = await tickMath.getSqrtRatioAtTick_986cfba3(new BN(MIN_TICK).toTwos(24).toString());
      const result = encodePriceSqrt(1, BigNumber.from(2).pow(127))
      expect(res[0].toNumber()).to.be.lt(result.toNumber())
    })

    it('max tick ratio is greater than js implementation', async () => {
      const res = await tickMath.getSqrtRatioAtTick_986cfba3(new BN(MAX_TICK).toString());
      const result = encodePriceSqrt(BigNumber.from(2).pow(127), 1);
      expect(BigNumber.from(res[0].toString())).to.be.gt(result)
    })

    it('max tick', async () => {
      const res = await tickMath.getSqrtRatioAtTick_986cfba3(new BN(MAX_TICK).toString());
      expect(res[0].toString()).to.eq("1461446703485210103287273052203988822378723970342")
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
          it('is at most off by 1/100th of a bips', async () => {
            const jsResult = new Decimal(1.0001).pow(tick).sqrt().mul(new Decimal(2).pow(96))
            const result = await tickMath.getSqrtRatioAtTick_986cfba3(new BN(tick).toTwos(24).toString())
            const absDiff = new Decimal(result.toString()).sub(jsResult).abs()
            expect(absDiff.div(jsResult).toNumber()).to.be.lt(0.000001)
          })
          /*
          it('result', async () => {
            expect((await tickMath.getSqrtRatioAtTick_986cfba3(tick)).toString()).to.matchSnapshot()
          })
          
          it('gas', async () => {
            await snapshotGasCost(tickMath.getGasCostOfgetSqrtRatioAtTick_986cfba3(tick))
          })*/
        })
      }
    }
  })

  describe('#MIN_SQRT_RATIO', async () => {
    it('equals #getSqrtRatioAtTick(MIN_TICK)', async () => {
      const min = await tickMath.getSqrtRatioAtTick_986cfba3(new BN(MIN_TICK).toTwos(24).toString())
      const result = await tickMath.MIN_SQRT_RATIO_ee8847ff()
      expect(min[0].toNumber()).to.eq(result[0].toNumber())
      expect(min[0].toNumber()).to.eq(MIN_SQRT_RATIO)
    })
  })

  describe('#MAX_SQRT_RATIO', async () => {
    it('equals #getSqrtRatioAtTick(MAX_TICK)', async () => {
      const max = await tickMath.getSqrtRatioAtTick_986cfba3(new BN(MAX_TICK).toString())
      const result = await tickMath.MAX_SQRT_RATIO_6d2cc304()
      expect(max[0].toString()).to.eq(result[0].toString())
      expect(max[0].toString()).to.eq(MAX_SQRT_RATIO.toString())
    })
  })

  describe('#getTickAtSqrtRatio', () => {
    /*
    it('throws for too low', async () => {
      expect(await tickMath.getTickAtSqrtRatio_4f76c058((MIN_SQRT_RATIO.sub(1)).toString())).to.be.revertedWith('R')
    })

    it('throws for too high', async () => {
      expect(await tickMath.getTickAtSqrtRatio_4f76c058((MAX_SQRT_RATIO).toString())).to.be.revertedWith('R')
    })
    */
    it('ratio of min tick', async () => {
      const result = await tickMath.getTickAtSqrtRatio_4f76c058("4295128739")
      expect(result[0].toString()).to.eq(new BN(MIN_TICK).toTwos(24).toString())
    })
    it('ratio of min tick + 1', async () => {
      const result = await tickMath.getTickAtSqrtRatio_4f76c058('4295343490')
      expect(result[0].toString()).to.eq(new BN(MIN_TICK + 1).toTwos(24).toString())
    })
    it('ratio of max tick - 1', async () => {
      const result = await tickMath.getTickAtSqrtRatio_4f76c058('1461373636630004318706518188784493106690254656249')
      expect(result[0].toString()).to.eq(new BN(MAX_TICK - 1).toString())
    })
    it('ratio closest to max tick', async () => {
      const result = await tickMath.getTickAtSqrtRatio_4f76c058((MAX_SQRT_RATIO.sub(1)).toString())
      expect(result[0].toNumber()).to.eq(MAX_TICK - 1)
    })
/*
    for (const ratio of [
      MIN_SQRT_RATIO,
      encodePriceSqrt((BigNumber.from(10).pow(12)).toString(), 1),
      encodePriceSqrt(BigNumber.from(10).pow(6), 1),
      encodePriceSqrt(1, 64),
      encodePriceSqrt(1, 8),
      encodePriceSqrt(1, 2),
      encodePriceSqrt(1, 1),
      encodePriceSqrt(2, 1),
      encodePriceSqrt(8, 1),
      encodePriceSqrt(64, 1),
      encodePriceSqrt(1, BigNumber.from(10).pow(6)),
      encodePriceSqrt(1, BigNumber.from(10).pow(12)),
      MAX_SQRT_RATIO.sub(1),
    ]) {
      describe(`ratio ${ratio}`, () => {
        it('is at most off by 1', async () => {
          const jsResult = new Decimal(ratio.toString()).div(new Decimal(2).pow(96)).pow(2).log(1.0001).floor()
          const result = await tickMath.getTickAtSqrtRatio_4f76c058(ratio.toString())
          const absDiff = new Decimal(result[0].toString()).sub(jsResult).abs()
          expect(absDiff.toNumber()).to.be.lte(1)
        })
        
        it('ratio is between the tick and tick+1', async () => {
          const tick = await tickMath.getTickAtSqrtRatio_4f76c058(ratio.toString())
          const ratioOfTick = await tickMath.getSqrtRatioAtTick_986cfba3(tick[0].toString())
          const ratioOfTickPlusOne = await tickMath.getSqrtRatioAtTick_986cfba3(tick[0].addn(1).toString())
          expect(BigNumber.from(ratio)).to.be.gte(BigNumber.from(ratioOfTick[0].toString()))
          expect(BigNumber.from(ratio)).to.be.lt(BigNumber.from(ratioOfTickPlusOne[0].toString()))
        })
        /*
        it('result', async () => {
          expect(await tickMath.getTickAtSqrtRatio_4f76c058(ratio.toString())).to.matchSnapshot()
        })
        
        it('gas', async () => {
          await snapshotGasCost(tickMath.getGasCostOfgetTickAtSqrtRatio_4f76c058(ratio))
        })
      })
    }*/
  })
})
