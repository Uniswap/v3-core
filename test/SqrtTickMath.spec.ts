import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import { SqrtTickMathTest } from '../typechain/SqrtTickMathTest'
import { expect } from './shared/expect'

const MIN_TICK = -887272
const MAX_TICK = 887272

describe('SqrtTickMath', () => {
  let sqrtTickMath: SqrtTickMathTest

  before('deploy TickMathTest', async () => {
    const sqrtTickMathTestFactory = await ethers.getContractFactory('SqrtTickMathTest')
    sqrtTickMath = (await sqrtTickMathTestFactory.deploy()) as SqrtTickMathTest
  })

  describe('#getSqrtRatioAtTick', () => {
    it('throws for too low', async () => {
      await expect(sqrtTickMath.getSqrtRatioAtTick(MIN_TICK - 1)).to.be.revertedWith(
        'TickMath::getRatioAtTick: invalid tick'
      )
    })

    it('throws for too low', async () => {
      await expect(sqrtTickMath.getSqrtRatioAtTick(MAX_TICK + 1)).to.be.revertedWith(
        'TickMath::getRatioAtTick: invalid tick'
      )
    })

    it('min tick', async () => {
      expect((await sqrtTickMath.getSqrtRatioAtTick(MIN_TICK))._x).to.eq('4295128739')
    })

    it('min tick +1', async () => {
      expect((await sqrtTickMath.getSqrtRatioAtTick(MIN_TICK + 1))._x).to.eq('4295343490')
    })

    it('max tick - 1', async () => {
      expect((await sqrtTickMath.getSqrtRatioAtTick(MAX_TICK - 1))._x).to.eq(
        '1461373636630004318706518188784493106690254656249'
      )
    })
    it('max tick', async () => {
      expect((await sqrtTickMath.getSqrtRatioAtTick(MAX_TICK))._x).to.eq(
        '1461446703485210103287273052203988822378723970342'
      )
    })
  })

  describe('#getTickAtSqrtRatio', () => {
    it('throws for too low', async () => {
      await expect(sqrtTickMath.getTickAtSqrtRatio({ _x: BigNumber.from('4295128738').sub(1) })).to.be.revertedWith(
        'TickMath::getTickAtRatio: invalid ratio'
      )
    })

    it('throws for too high', async () => {
      await expect(
        sqrtTickMath.getTickAtSqrtRatio({
          _x: BigNumber.from('1461446703485210103287273052203988822378723970342').add(1),
        })
      ).to.be.revertedWith('TickMath::getTickAtRatio: invalid ratio')
    })

    it('ratio of min tick', async () => {
      expect(await sqrtTickMath.getTickAtSqrtRatio({ _x: '4295128739' })).to.eq(MIN_TICK)
    })
    it('ratio of min tick + 1', async () => {
      expect(await sqrtTickMath.getTickAtSqrtRatio({ _x: '4295343490' })).to.eq(MIN_TICK + 1)
    })
    it('ratio of max tick - 1', async () => {
      expect(await sqrtTickMath.getTickAtSqrtRatio({ _x: '1461373636630004318706518188784493106690254656249' })).to.eq(
        MAX_TICK - 1
      )
    })
    it('ratio closest to max tick', async () => {
      expect(
        await sqrtTickMath.getTickAtSqrtRatio({
          _x: BigNumber.from('1461446703485210103287273052203988822378723970342').sub(1),
        })
      ).to.eq(MAX_TICK - 1)
    })
  })
})
