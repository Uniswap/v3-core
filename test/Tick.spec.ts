import { ethers } from 'hardhat'
import { BigNumber } from 'ethers'
import { TickTest } from '../typechain/TickTest'
import { expect } from './shared/expect'
import { FeeAmount, getMaxLiquidityPerTick, getMaxTick, getMinTick, TICK_SPACINGS } from './shared/utilities'

const MaxUint128 = BigNumber.from(2).pow(128).sub(1)

describe('TickTest', () => {
  let tickTest: TickTest

  before('deploy TickTest', async () => {
    const tickTestFactory = await ethers.getContractFactory('TickTest')
    tickTest = (await tickTestFactory.deploy()) as TickTest
  })

  describe('#tickSpacingToParameters', () => {
    it('returns the correct value for low fee', async () => {
      const { minTick, maxTick, maxLiquidityPerTick } = await tickTest.tickSpacingToParameters(
        TICK_SPACINGS[FeeAmount.LOW]
      )
      expect(minTick).to.eq(-887268)
      expect(minTick).to.eq(getMinTick(TICK_SPACINGS[FeeAmount.LOW]))
      expect(maxTick).to.eq(887268)
      expect(maxTick).to.eq(getMaxTick(TICK_SPACINGS[FeeAmount.LOW]))
      expect(maxLiquidityPerTick).to.eq('2301086475570827930019641784376200') // 110.8 bits
      expect(maxLiquidityPerTick).to.eq(getMaxLiquidityPerTick(TICK_SPACINGS[FeeAmount.LOW]))
    })
    it('returns the correct value for medium fee', async () => {
      const { minTick, maxTick, maxLiquidityPerTick } = await tickTest.tickSpacingToParameters(
        TICK_SPACINGS[FeeAmount.MEDIUM]
      )
      expect(minTick).to.eq(-887220)
      expect(minTick).to.eq(getMinTick(TICK_SPACINGS[FeeAmount.MEDIUM]))
      expect(maxTick).to.eq(887220)
      expect(maxTick).to.eq(getMaxTick(TICK_SPACINGS[FeeAmount.MEDIUM]))
      expect(maxLiquidityPerTick).to.eq('11505743598341114571880798222544994') // 113.1 bits
      expect(maxLiquidityPerTick).to.eq(getMaxLiquidityPerTick(TICK_SPACINGS[FeeAmount.MEDIUM]))
    })
    it('returns the correct value for high fee', async () => {
      const { minTick, maxTick, maxLiquidityPerTick } = await tickTest.tickSpacingToParameters(
        TICK_SPACINGS[FeeAmount.HIGH]
      )
      expect(minTick).to.eq(-887220)
      expect(minTick).to.eq(getMinTick(TICK_SPACINGS[FeeAmount.HIGH]))
      expect(maxTick).to.eq(887220)
      expect(maxTick).to.eq(getMaxTick(TICK_SPACINGS[FeeAmount.HIGH]))
      expect(maxLiquidityPerTick).to.eq('34514896736072468147213166389265464') // 114.7 bits
      expect(maxLiquidityPerTick).to.eq(getMaxLiquidityPerTick(TICK_SPACINGS[FeeAmount.HIGH]))
    })
    it('returns the correct value for entire range', async () => {
      const { minTick, maxTick, maxLiquidityPerTick } = await tickTest.tickSpacingToParameters(887272)
      expect(minTick).to.eq(-887272)
      expect(minTick).to.eq(getMinTick(887272))
      expect(maxTick).to.eq(887272)
      expect(maxTick).to.eq(getMaxTick(887272))
      expect(maxLiquidityPerTick).to.eq(MaxUint128.div(3)) // 126 bits
      expect(maxLiquidityPerTick).to.eq(getMaxLiquidityPerTick(887272))
    })
    it('returns the correct value for 2302', async () => {
      const { minTick, maxTick, maxLiquidityPerTick } = await tickTest.tickSpacingToParameters(2302)
      expect(minTick).to.eq(-886270)
      expect(minTick).to.eq(getMinTick(2302))
      expect(maxTick).to.eq(886270)
      expect(maxTick).to.eq(getMaxTick(2302))
      expect(maxLiquidityPerTick).to.eq('441351967472034323558203122479595605') // 118 bits
      expect(maxLiquidityPerTick).to.eq(getMaxLiquidityPerTick(2302))
    })
  })
})
