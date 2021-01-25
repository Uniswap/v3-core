import { ethers, waffle } from 'hardhat'
import { SecondsOutsideTest } from '../typechain/SecondsOutsideTest'
import { expect } from './shared/expect'
import { TEST_PAIR_START_TIME } from './shared/fixtures'

const { BigNumber } = ethers

const { loadFixture } = waffle

describe('SecondsOutside', () => {
  let secondsOutside: SecondsOutsideTest

  const secondsOutsideFixture = async () => {
    const secondsOutsideFactory = await ethers.getContractFactory('SecondsOutsideTest')
    return (await secondsOutsideFactory.deploy()) as SecondsOutsideTest
  }

  beforeEach('deploy SecondsOutsideTest', async () => {
    secondsOutside = await loadFixture(secondsOutsideFixture)
  })

  describe('#initialize', () => {
    it('reverts if tick is not multiple of tickSpacing', async () => {
      await expect(secondsOutside.initialize(1, 8, 4, TEST_PAIR_START_TIME)).to.be.revertedWith('TS')
    })
    it('tick 0 at current tick', async () => {
      const tick = 0
      const tickCurrent = 0
      const tickSpacing = 3
      await secondsOutside.initialize(tick, tickCurrent, tickSpacing, TEST_PAIR_START_TIME)
      expect(await secondsOutside.secondsOutside(0)).to.eq(TEST_PAIR_START_TIME)
      expect(await secondsOutside.get(tick, tickSpacing)).to.eq(TEST_PAIR_START_TIME)
    })
    it('tick 0 above current tick', async () => {
      const tick = 0
      const tickCurrent = -3
      const tickSpacing = 3
      await secondsOutside.initialize(tick, tickCurrent, tickSpacing, TEST_PAIR_START_TIME)
      expect(await secondsOutside.secondsOutside(0)).to.eq(0)
      expect(await secondsOutside.get(tick, tickSpacing)).to.eq(0)
    })
    it('tick 0 below current tick', async () => {
      const tick = 0
      const tickCurrent = 3
      const tickSpacing = 3
      await secondsOutside.initialize(tick, tickCurrent, tickSpacing, TEST_PAIR_START_TIME)
      expect(await secondsOutside.secondsOutside(0)).to.eq(TEST_PAIR_START_TIME)
      expect(await secondsOutside.get(tick, tickSpacing)).to.eq(TEST_PAIR_START_TIME)
    })
    it('tick 21 at current tick', async () => {
      const tick = 21
      const tickCurrent = 21
      const tickSpacing = 3
      await secondsOutside.initialize(tick, tickCurrent, tickSpacing, TEST_PAIR_START_TIME)
      expect(await secondsOutside.secondsOutside(0)).to.eq(BigNumber.from(TEST_PAIR_START_TIME).shl(224))
      expect(await secondsOutside.get(tick, tickSpacing)).to.eq(TEST_PAIR_START_TIME)
    })
    it('tick 21 above current tick', async () => {
      const tick = 21
      const tickCurrent = 20
      const tickSpacing = 3
      await secondsOutside.initialize(tick, tickCurrent, tickSpacing, TEST_PAIR_START_TIME)
      expect(await secondsOutside.secondsOutside(0)).to.eq(0)
      expect(await secondsOutside.get(tick, tickSpacing)).to.eq(0)
    })
    it('tick 21 below current tick', async () => {
      const tick = 21
      const tickCurrent = 22
      const tickSpacing = 3
      await secondsOutside.initialize(tick, tickCurrent, tickSpacing, TEST_PAIR_START_TIME)
      expect(await secondsOutside.secondsOutside(0)).to.eq(BigNumber.from(TEST_PAIR_START_TIME).shl(224))
      expect(await secondsOutside.get(tick, tickSpacing)).to.eq(TEST_PAIR_START_TIME)
    })
    it('sets the right value for positive ticks above the current tick', async () => {
      const tick = 33
      const tickCurrent = 0
      const tickSpacing = 3
      await secondsOutside.initialize(tick, tickCurrent, tickSpacing, TEST_PAIR_START_TIME)
      expect(await secondsOutside.secondsOutside(1)).to.eq(0)
      expect(await secondsOutside.get(tick, tickSpacing)).to.eq(0)
    })

    it('sets the right value for positive ticks at the current tick', async () => {
      const tick = 33
      const tickCurrent = 33
      const tickSpacing = 3
      await secondsOutside.initialize(tick, tickCurrent, tickSpacing, TEST_PAIR_START_TIME)
      expect(await secondsOutside.secondsOutside(1)).to.eq(BigNumber.from(TEST_PAIR_START_TIME).shl(96))
      expect(await secondsOutside.get(tick, tickSpacing)).to.eq(TEST_PAIR_START_TIME)
    })

    it('sets the right value for positive ticks below the current tick', async () => {
      const tick = 33
      const tickCurrent = 39
      const tickSpacing = 3
      await secondsOutside.initialize(tick, tickCurrent, tickSpacing, TEST_PAIR_START_TIME)
      expect(await secondsOutside.secondsOutside(1)).to.eq(BigNumber.from(TEST_PAIR_START_TIME).shl(96))
      expect(await secondsOutside.get(tick, tickSpacing)).to.eq(TEST_PAIR_START_TIME)
    })

    it('negative tickCurrent above negative tick', async () => {
      const tick = -33
      const tickCurrent = -30
      const tickSpacing = 3
      await secondsOutside.initialize(tick, tickCurrent, tickSpacing, TEST_PAIR_START_TIME)
      expect(await secondsOutside.secondsOutside(-2)).to.eq(BigNumber.from(TEST_PAIR_START_TIME).shl(160))
      expect(await secondsOutside.get(tick, tickSpacing)).to.eq(TEST_PAIR_START_TIME)
    })

    it('negative tickCurrent at negative tick', async () => {
      const tick = -33
      const tickCurrent = -33
      const tickSpacing = 3
      await secondsOutside.initialize(tick, tickCurrent, tickSpacing, TEST_PAIR_START_TIME)
      expect(await secondsOutside.secondsOutside(-2)).to.eq(BigNumber.from(TEST_PAIR_START_TIME).shl(160))
      expect(await secondsOutside.get(tick, tickSpacing)).to.eq(TEST_PAIR_START_TIME)
    })

    it('negative tickCurrent below negative tick', async () => {
      const tick = -33
      const tickCurrent = -36
      const tickSpacing = 3
      await secondsOutside.initialize(tick, tickCurrent, tickSpacing, TEST_PAIR_START_TIME)
      expect(await secondsOutside.secondsOutside(-2)).to.eq(0)
      expect(await secondsOutside.get(tick, tickSpacing)).to.eq(0)
    })

    it('combined two ticks in same word where only lower is set', async () => {
      await secondsOutside.initialize(1, 1, 1, TEST_PAIR_START_TIME)
      await secondsOutside.initialize(2, 1, 1, TEST_PAIR_START_TIME + 1)
      expect(await secondsOutside.get(1, 1)).to.eq(TEST_PAIR_START_TIME)
      expect(await secondsOutside.get(2, 1)).to.eq(0)
    })

    it('combined two ticks in same word where both are set', async () => {
      await secondsOutside.initialize(1, 2, 1, TEST_PAIR_START_TIME)
      await secondsOutside.initialize(2, 2, 1, TEST_PAIR_START_TIME + 1)
      expect(await secondsOutside.get(1, 1)).to.eq(TEST_PAIR_START_TIME)
      expect(await secondsOutside.get(2, 1)).to.eq(TEST_PAIR_START_TIME + 1)
    })

    it('combined two ticks in same word where neither are set', async () => {
      await secondsOutside.initialize(1, 0, 1, TEST_PAIR_START_TIME)
      await secondsOutside.initialize(2, 0, 1, TEST_PAIR_START_TIME + 1)
      expect(await secondsOutside.get(1, 1)).to.eq(0)
      expect(await secondsOutside.get(2, 1)).to.eq(0)
    })
  })

  describe('#clear', () => {
    it('removes the tick data', async () => {
      await secondsOutside.initialize(1, 2, 1, TEST_PAIR_START_TIME)
      await secondsOutside.initialize(2, 2, 1, TEST_PAIR_START_TIME + 1)
      await secondsOutside.clear(1, 1)
      expect(await secondsOutside.get(1, 1)).to.eq(0)
      expect(await secondsOutside.get(2, 1)).to.eq(TEST_PAIR_START_TIME + 1)
    })
  })

  describe('#cross', () => {
    it('flips the tick', async () => {
      await secondsOutside.initialize(1, 1, 1, TEST_PAIR_START_TIME)
      await secondsOutside.cross(1, 1, TEST_PAIR_START_TIME + 2)
      expect(await secondsOutside.get(1, 1)).to.eq(2)
    })

    it('flips the tick twice', async () => {
      await secondsOutside.initialize(1, 1, 1, TEST_PAIR_START_TIME)
      await secondsOutside.cross(1, 1, TEST_PAIR_START_TIME + 2)
      await secondsOutside.cross(1, 1, TEST_PAIR_START_TIME + 4)
      expect(await secondsOutside.get(1, 1)).to.eq(TEST_PAIR_START_TIME + 2)
    })
  })

  describe('#secondsInside', () => {
    describe('starts inside range', () => {
      it('is correct if tick is inside range', async () => {
        await secondsOutside.initialize(1, 2, 1, TEST_PAIR_START_TIME)
        await secondsOutside.initialize(4, 2, 1, TEST_PAIR_START_TIME)
        expect(await secondsOutside.secondsInside(1, 4, 3, 1, TEST_PAIR_START_TIME + 15)).to.eq(15)
      })
      it('is correct if tick is above range', async () => {
        await secondsOutside.initialize(1, 2, 1, TEST_PAIR_START_TIME)
        await secondsOutside.initialize(4, 2, 1, TEST_PAIR_START_TIME)
        await secondsOutside.cross(4, 1, TEST_PAIR_START_TIME + 10)
        expect(await secondsOutside.secondsInside(1, 4, 6, 1, TEST_PAIR_START_TIME + 15)).to.eq(10)
      })
      it('is correct if tick is below range', async () => {
        await secondsOutside.initialize(1, 2, 1, TEST_PAIR_START_TIME)
        await secondsOutside.initialize(4, 2, 1, TEST_PAIR_START_TIME)
        await secondsOutside.cross(1, 1, TEST_PAIR_START_TIME + 9)
        expect(await secondsOutside.secondsInside(1, 4, 0, 1, TEST_PAIR_START_TIME + 32)).to.eq(9)
      })
    })

    describe('starts below range', () => {
      it('is correct if tick is inside range', async () => {
        await secondsOutside.initialize(1, 0, 1, TEST_PAIR_START_TIME)
        await secondsOutside.initialize(4, 0, 1, TEST_PAIR_START_TIME)
        await secondsOutside.cross(1, 1, TEST_PAIR_START_TIME + 5)
        expect(await secondsOutside.secondsInside(1, 4, 2, 1, TEST_PAIR_START_TIME + 15)).to.eq(10)
      })
      it('is correct if tick is above range', async () => {
        await secondsOutside.initialize(1, 0, 1, TEST_PAIR_START_TIME)
        await secondsOutside.initialize(4, 0, 1, TEST_PAIR_START_TIME)
        await secondsOutside.cross(1, 1, TEST_PAIR_START_TIME + 10)
        await secondsOutside.cross(4, 1, TEST_PAIR_START_TIME + 15)
        expect(await secondsOutside.secondsInside(1, 4, 6, 1, TEST_PAIR_START_TIME + 20)).to.eq(5)
      })
      it('is correct if tick is below range', async () => {
        await secondsOutside.initialize(1, 0, 1, TEST_PAIR_START_TIME)
        await secondsOutside.initialize(4, 0, 1, TEST_PAIR_START_TIME)
        expect(await secondsOutside.secondsInside(1, 4, 0, 1, TEST_PAIR_START_TIME + 32)).to.eq(0)
      })
    })

    describe('starts above range', () => {
      it('is correct if tick is inside range', async () => {
        await secondsOutside.initialize(1, 5, 1, TEST_PAIR_START_TIME)
        await secondsOutside.initialize(4, 5, 1, TEST_PAIR_START_TIME)
        await secondsOutside.cross(4, 1, TEST_PAIR_START_TIME + 5)
        expect(await secondsOutside.secondsInside(1, 4, 2, 1, TEST_PAIR_START_TIME + 15)).to.eq(10)
      })
      it('is correct if tick is above range', async () => {
        await secondsOutside.initialize(1, 5, 1, TEST_PAIR_START_TIME)
        await secondsOutside.initialize(4, 5, 1, TEST_PAIR_START_TIME)
        expect(await secondsOutside.secondsInside(1, 4, 6, 1, TEST_PAIR_START_TIME + 20)).to.eq(0)
      })
      it('is correct if tick is below range', async () => {
        await secondsOutside.initialize(1, 5, 1, TEST_PAIR_START_TIME)
        await secondsOutside.initialize(4, 5, 1, TEST_PAIR_START_TIME)
        await secondsOutside.cross(4, 1, TEST_PAIR_START_TIME + 10)
        await secondsOutside.cross(1, 1, TEST_PAIR_START_TIME + 15)
        expect(await secondsOutside.secondsInside(1, 4, 0, 1, TEST_PAIR_START_TIME + 32)).to.eq(5)
      })
    })
  })
})
