import {ethers} from 'hardhat'
import {TickBitMapTest} from '../typechain/TickBitMapTest'
import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {MAX_TICK, MIN_TICK} from './shared/utilities'

describe('TickBitMap', () => {
  let tickBitMap: TickBitMapTest

  beforeEach('deploy TickBitMapTest', async () => {
    const tickBitMapTestFactory = await ethers.getContractFactory('TickBitMapTest')
    tickBitMap = (await tickBitMapTestFactory.deploy()) as TickBitMapTest
  })

  async function initTicks(ticks: number[]): Promise<void> {
    for (const tick of ticks) {
      await tickBitMap.flipTick(tick)
    }
  }

  describe('#isInitialized', () => {
    it('is false at first', async () => {
      expect(await tickBitMap.isInitialized(1)).to.eq(false)
    })
    it('is flipped by #flipTick', async () => {
      await tickBitMap.flipTick(1)
      expect(await tickBitMap.isInitialized(1)).to.eq(true)
    })
    it('is flipped back by #flipTick', async () => {
      await tickBitMap.flipTick(1)
      await tickBitMap.flipTick(1)
      expect(await tickBitMap.isInitialized(1)).to.eq(false)
    })
    it('is not changed by another flip to a different tick', async () => {
      await tickBitMap.flipTick(2)
      expect(await tickBitMap.isInitialized(1)).to.eq(false)
    })
    it('is not changed by another flip to a different tick on another word', async () => {
      await tickBitMap.flipTick(1 + 256)
      expect(await tickBitMap.isInitialized(257)).to.eq(true)
      expect(await tickBitMap.isInitialized(1)).to.eq(false)
    })
    it('works for MIN_TICK', async () => {
      expect(await tickBitMap.isInitialized(MIN_TICK)).to.eq(false)
    })
    it('works for MAX_TICK', async () => {
      expect(await tickBitMap.isInitialized(MAX_TICK)).to.eq(false)
    })
    it('throws on less than MIN_TICK', async () => {
      await expect(tickBitMap.isInitialized(MIN_TICK - 1)).to.be.revertedWith(
        'TickBitMap::position: tick must be greater than or equal to MIN_TICK'
      )
    })
    it('throws on greater than MAX_TICK', async () => {
      await expect(tickBitMap.isInitialized(MAX_TICK + 1)).to.be.revertedWith(
        'TickBitMap::position: tick must be less than or equal to MAX_TICK'
      )
    })
    it('gas if tick is not initialized', async () => {
      await snapshotGasCost(tickBitMap.getGasCostOfIsInitialized(1))
    })
    it('gas if tick is initialized', async () => {
      await tickBitMap.flipTick(1)
      await snapshotGasCost(tickBitMap.getGasCostOfIsInitialized(1))
    })
  })

  describe('#flipTick', () => {
    it('flips only the specified tick', async () => {
      await tickBitMap.flipTick(-230)
      expect(await tickBitMap.isInitialized(-230)).to.eq(true)
      expect(await tickBitMap.isInitialized(-231)).to.eq(false)
      expect(await tickBitMap.isInitialized(-229)).to.eq(false)
      expect(await tickBitMap.isInitialized(-230 + 256)).to.eq(false)
      expect(await tickBitMap.isInitialized(-230 - 256)).to.eq(false)
      await tickBitMap.flipTick(-230)
      expect(await tickBitMap.isInitialized(-230)).to.eq(false)
      expect(await tickBitMap.isInitialized(-231)).to.eq(false)
      expect(await tickBitMap.isInitialized(-229)).to.eq(false)
      expect(await tickBitMap.isInitialized(-230 + 256)).to.eq(false)
      expect(await tickBitMap.isInitialized(-230 - 256)).to.eq(false)
    })

    it('reverts only itself', async () => {
      await tickBitMap.flipTick(-230)
      await tickBitMap.flipTick(-259)
      await tickBitMap.flipTick(-229)
      await tickBitMap.flipTick(500)
      await tickBitMap.flipTick(-259)
      await tickBitMap.flipTick(-229)
      await tickBitMap.flipTick(-259)

      expect(await tickBitMap.isInitialized(-259)).to.eq(true)
      expect(await tickBitMap.isInitialized(-229)).to.eq(false)
    })

    it('works for MIN_TICK', async () => {
      await tickBitMap.flipTick(MIN_TICK)
      expect(await tickBitMap.isInitialized(MIN_TICK)).to.eq(true)
    })
    it('works for MAX_TICK', async () => {
      await tickBitMap.flipTick(MAX_TICK)
      expect(await tickBitMap.isInitialized(MAX_TICK)).to.eq(true)
    })
    it('throws on less than MIN_TICK', async () => {
      await expect(tickBitMap.flipTick(MIN_TICK - 1)).to.be.revertedWith(
        'TickBitMap::position: tick must be greater than or equal to MIN_TICK'
      )
    })
    it('throws on greater than MAX_TICK', async () => {
      await expect(tickBitMap.flipTick(MAX_TICK + 1)).to.be.revertedWith(
        'TickBitMap::position: tick must be less than or equal to MAX_TICK'
      )
    })

    it('gas cost of flipping first tick in word to initialized', async () => {
      await snapshotGasCost(await tickBitMap.getGasCostOfFlipTick(1))
    })
    it('gas cost of flipping second tick in word to initialized', async () => {
      await tickBitMap.flipTick(0)
      await snapshotGasCost(await tickBitMap.getGasCostOfFlipTick(1))
    })
    it('gas cost of flipping a tick that results in deleting a word', async () => {
      await tickBitMap.flipTick(0)
      await snapshotGasCost(await tickBitMap.getGasCostOfFlipTick(0))
    })
  })

  describe('#nextInitializedTickWithinOneWord', () => {
    beforeEach('set up some ticks', async () => {
      // 73 is the first positive tick at the start of a word
      await initTicks([70, 78, 84, 139, 240])
    })

    describe('lte = false', async () => {
      it('returns tick to right if at initialized tick', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(78, false)
        expect(next).to.eq(84)
        expect(initialized).to.eq(true)
      })
      it('returns the tick directly to the right', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(77, false)
        expect(next).to.eq(78)
        expect(initialized).to.eq(true)
      })
      it('returns the next words initialized tick if on the right boundary', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(328, false)
        expect(next).to.eq(584)
        expect(initialized).to.eq(false)
      })
      it('returns the next initialized tick from the next word', async () => {
        await tickBitMap.flipTick(340)
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(328, false)
        expect(next).to.eq(340)
        expect(initialized).to.eq(true)
      })
      it('does not exceed boundary', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(70, false)
        expect(next).to.eq(72)
        expect(initialized).to.eq(false)
      })
      it('skips entire word', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(329, false)
        expect(next).to.eq(584)
        expect(initialized).to.eq(false)
      })
      it('skips half word', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(456, false)
        expect(next).to.eq(584)
        expect(initialized).to.eq(false)
      })

      it('gas cost on boundary', async () => {
        await snapshotGasCost(await tickBitMap.getGasCostOfNextInitializedTickWithinOneWord(78, false))
      })
      it('gas cost just below boundary', async () => {
        await snapshotGasCost(await tickBitMap.getGasCostOfNextInitializedTickWithinOneWord(77, false))
      })
      it('gas cost for entire word', async () => {
        await snapshotGasCost(await tickBitMap.getGasCostOfNextInitializedTickWithinOneWord(329, false))
      })
    })

    describe('lte = true', () => {
      it('returns same tick if initialized', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(78, true)

        expect(next).to.eq(78)
        expect(initialized).to.eq(true)
      })
      it('returns tick directly to the left of input tick if not initialized', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(79, true)

        expect(next).to.eq(78)
        expect(initialized).to.eq(true)
      })
      it('will not exceed the word boundary', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(73, true)

        expect(next).to.eq(73)
        expect(initialized).to.eq(false)
      })
      it('at the word boundary', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(73, true)

        expect(next).to.eq(73)
        expect(initialized).to.eq(false)
      })
      it('word boundary less 1 (next initialized tick in next word)', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(72, true)

        expect(next).to.eq(70)
        expect(initialized).to.eq(true)
      })
      it('word boundary', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(69, true)

        expect(next).to.eq(-183)
        expect(initialized).to.eq(false)
      })
      it('entire empty word', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(584, true)

        expect(next).to.eq(329)
        expect(initialized).to.eq(false)
      })
      it('halfway through empty word', async () => {
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(456, true)

        expect(next).to.eq(329)
        expect(initialized).to.eq(false)
      })
      it('boundary is initialized', async () => {
        await tickBitMap.flipTick(329)
        const {next, initialized} = await tickBitMap.nextInitializedTickWithinOneWord(456, true)

        expect(next).to.eq(329)
        expect(initialized).to.eq(true)
      })

      it('gas cost on boundary', async () => {
        await snapshotGasCost(await tickBitMap.getGasCostOfNextInitializedTickWithinOneWord(78, true))
      })
      it('gas cost just below boundary', async () => {
        await snapshotGasCost(await tickBitMap.getGasCostOfNextInitializedTickWithinOneWord(77, true))
      })
      it('gas cost for entire word', async () => {
        await snapshotGasCost(await tickBitMap.getGasCostOfNextInitializedTickWithinOneWord(584, true))
      })
    })
  })

  describe('#nextInitializedTick', () => {
    it('fails if not initialized', async () => {
      await expect(tickBitMap.nextInitializedTick(0, true)).to.be.revertedWith(
        'TickMath::nextInitializedTick: no initialized next tick'
      )
      await expect(tickBitMap.nextInitializedTick(0, false)).to.be.revertedWith(
        'TickMath::nextInitializedTick: no initialized next tick'
      )
    })
    describe('initialized', () => {
      beforeEach(() => initTicks([MIN_TICK, -1259, 73, 529, 2350, MAX_TICK]))
      describe('lte = false', () => {
        it('one iteration', async () => {
          expect(await tickBitMap.nextInitializedTick(480, false)).to.eq(529)
        })
        it('starting from initialized tick', async () => {
          expect(await tickBitMap.nextInitializedTick(529, false)).to.eq(2350)
          expect(await tickBitMap.nextInitializedTick(2350, false)).to.eq(MAX_TICK)
        })
        it('starting from just before initialized tick', async () => {
          expect(await tickBitMap.nextInitializedTick(72, false)).to.eq(73)
          expect(await tickBitMap.nextInitializedTick(528, false)).to.eq(529)
        })
        it('multiple iterations', async () => {
          expect(await tickBitMap.nextInitializedTick(120, false)).to.eq(529)
        })
        it('gas cost single iteration', async () => {
          await snapshotGasCost(tickBitMap.getGasCostOfNextInitializedTick(400, false))
        })
        it('gas cost many iterations', async () => {
          await snapshotGasCost(tickBitMap.getGasCostOfNextInitializedTick(2350, false))
        })
      })
      describe('lte = true', () => {
        it('one iteration', async () => {
          expect(await tickBitMap.nextInitializedTick(-1230, true)).to.eq(-1259)
        })
        it('starting from initialized tick', async () => {
          expect(await tickBitMap.nextInitializedTick(529, true)).to.eq(529)
        })
        it('getting to MIN_TICK', async () => {
          expect(await tickBitMap.nextInitializedTick(-1260, true)).to.eq(MIN_TICK)
        })
        it('multiple iterations', async () => {
          expect(await tickBitMap.nextInitializedTick(528, true)).to.eq(73)
          expect(await tickBitMap.nextInitializedTick(2349, true)).to.eq(529)
        })
        it('gas cost single iteration', async () => {
          await snapshotGasCost(tickBitMap.getGasCostOfNextInitializedTick(124, true))
        })
        it('gas cost many iterations', async () => {
          await snapshotGasCost(tickBitMap.getGasCostOfNextInitializedTick(2349, true))
        })
      })
    })
  })
})
