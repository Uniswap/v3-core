import {ethers} from 'hardhat'
import {TickBitmapTest} from '../typechain/TickBitmapTest'
import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {MAX_TICK, MIN_TICK} from './shared/utilities'

describe('TickBitmap', () => {
  let TickBitmap: TickBitmapTest

  beforeEach('deploy TickBitmapTest', async () => {
    const TickBitmapTestFactory = await ethers.getContractFactory('TickBitmapTest')
    TickBitmap = (await TickBitmapTestFactory.deploy()) as TickBitmapTest
  })

  async function initTicks(ticks: number[]): Promise<void> {
    for (const tick of ticks) {
      await TickBitmap.flipTick(tick)
    }
  }

  describe('#isInitialized', () => {
    it('is false at first', async () => {
      expect(await TickBitmap.isInitialized(1)).to.eq(false)
    })
    it('is flipped by #flipTick', async () => {
      await TickBitmap.flipTick(1)
      expect(await TickBitmap.isInitialized(1)).to.eq(true)
    })
    it('is flipped back by #flipTick', async () => {
      await TickBitmap.flipTick(1)
      await TickBitmap.flipTick(1)
      expect(await TickBitmap.isInitialized(1)).to.eq(false)
    })
    it('is not changed by another flip to a different tick', async () => {
      await TickBitmap.flipTick(2)
      expect(await TickBitmap.isInitialized(1)).to.eq(false)
    })
    it('is not changed by another flip to a different tick on another word', async () => {
      await TickBitmap.flipTick(1 + 256)
      expect(await TickBitmap.isInitialized(257)).to.eq(true)
      expect(await TickBitmap.isInitialized(1)).to.eq(false)
    })
    it('gas if tick is not initialized', async () => {
      await snapshotGasCost(TickBitmap.getGasCostOfIsInitialized(1))
    })
    it('gas if tick is initialized', async () => {
      await TickBitmap.flipTick(1)
      await snapshotGasCost(TickBitmap.getGasCostOfIsInitialized(1))
    })
  })

  describe('#flipTick', () => {
    it('flips only the specified tick', async () => {
      await TickBitmap.flipTick(-230)
      expect(await TickBitmap.isInitialized(-230)).to.eq(true)
      expect(await TickBitmap.isInitialized(-231)).to.eq(false)
      expect(await TickBitmap.isInitialized(-229)).to.eq(false)
      expect(await TickBitmap.isInitialized(-230 + 256)).to.eq(false)
      expect(await TickBitmap.isInitialized(-230 - 256)).to.eq(false)
      await TickBitmap.flipTick(-230)
      expect(await TickBitmap.isInitialized(-230)).to.eq(false)
      expect(await TickBitmap.isInitialized(-231)).to.eq(false)
      expect(await TickBitmap.isInitialized(-229)).to.eq(false)
      expect(await TickBitmap.isInitialized(-230 + 256)).to.eq(false)
      expect(await TickBitmap.isInitialized(-230 - 256)).to.eq(false)
    })

    it('reverts only itself', async () => {
      await TickBitmap.flipTick(-230)
      await TickBitmap.flipTick(-259)
      await TickBitmap.flipTick(-229)
      await TickBitmap.flipTick(500)
      await TickBitmap.flipTick(-259)
      await TickBitmap.flipTick(-229)
      await TickBitmap.flipTick(-259)

      expect(await TickBitmap.isInitialized(-259)).to.eq(true)
      expect(await TickBitmap.isInitialized(-229)).to.eq(false)
    })

    it('gas cost of flipping first tick in word to initialized', async () => {
      await snapshotGasCost(await TickBitmap.getGasCostOfFlipTick(1))
    })
    it('gas cost of flipping second tick in word to initialized', async () => {
      await TickBitmap.flipTick(0)
      await snapshotGasCost(await TickBitmap.getGasCostOfFlipTick(1))
    })
    it('gas cost of flipping a tick that results in deleting a word', async () => {
      await TickBitmap.flipTick(0)
      await snapshotGasCost(await TickBitmap.getGasCostOfFlipTick(0))
    })
  })

  describe('#nextInitializedTickWithinOneWord', () => {
    beforeEach('set up some ticks', async () => {
      // word boundaries are at multiples of 256
      await initTicks([70, 78, 84, 139, 240, 535])
    })

    describe('lte = false', async () => {
      it('returns tick to right if at initialized tick', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(78, false)
        expect(next).to.eq(84)
        expect(initialized).to.eq(true)
      })
      it('returns the tick directly to the right', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(77, false)
        expect(next).to.eq(78)
        expect(initialized).to.eq(true)
      })
      it('returns the next words initialized tick if on the right boundary', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(255, false)
        expect(next).to.eq(511)
        expect(initialized).to.eq(false)
      })
      it('returns the next initialized tick from the next word', async () => {
        await TickBitmap.flipTick(340)
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(328, false)
        expect(next).to.eq(340)
        expect(initialized).to.eq(true)
      })
      it('does not exceed boundary', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(508, false)
        expect(next).to.eq(511)
        expect(initialized).to.eq(false)
      })
      it('skips entire word', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(255, false)
        expect(next).to.eq(511)
        expect(initialized).to.eq(false)
      })
      it('skips half word', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(383, false)
        expect(next).to.eq(511)
        expect(initialized).to.eq(false)
      })

      it('gas cost on boundary', async () => {
        await snapshotGasCost(await TickBitmap.getGasCostOfNextInitializedTickWithinOneWord(255, false))
      })
      it('gas cost just below boundary', async () => {
        await snapshotGasCost(await TickBitmap.getGasCostOfNextInitializedTickWithinOneWord(254, false))
      })
      it('gas cost for entire word', async () => {
        await snapshotGasCost(await TickBitmap.getGasCostOfNextInitializedTickWithinOneWord(768, false))
      })
    })

    describe('lte = true', () => {
      it('returns same tick if initialized', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(78, true)

        expect(next).to.eq(78)
        expect(initialized).to.eq(true)
      })
      it('returns tick directly to the left of input tick if not initialized', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(79, true)

        expect(next).to.eq(78)
        expect(initialized).to.eq(true)
      })
      it('will not exceed the word boundary', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(258, true)

        expect(next).to.eq(256)
        expect(initialized).to.eq(false)
      })
      it('at the word boundary', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(256, true)

        expect(next).to.eq(256)
        expect(initialized).to.eq(false)
      })
      it('word boundary less 1 (next initialized tick in next word)', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(72, true)

        expect(next).to.eq(70)
        expect(initialized).to.eq(true)
      })
      it('word boundary', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(-1, true)

        expect(next).to.eq(-256)
        expect(initialized).to.eq(false)
      })
      it('entire empty word', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(1023, true)

        expect(next).to.eq(768)
        expect(initialized).to.eq(false)
      })
      it('halfway through empty word', async () => {
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(900, true)

        expect(next).to.eq(768)
        expect(initialized).to.eq(false)
      })
      it('boundary is initialized', async () => {
        await TickBitmap.flipTick(329)
        const {next, initialized} = await TickBitmap.nextInitializedTickWithinOneWord(456, true)

        expect(next).to.eq(329)
        expect(initialized).to.eq(true)
      })

      it('gas cost on boundary', async () => {
        await snapshotGasCost(await TickBitmap.getGasCostOfNextInitializedTickWithinOneWord(256, true))
      })
      it('gas cost just below boundary', async () => {
        await snapshotGasCost(await TickBitmap.getGasCostOfNextInitializedTickWithinOneWord(255, true))
      })
      it('gas cost for entire word', async () => {
        await snapshotGasCost(await TickBitmap.getGasCostOfNextInitializedTickWithinOneWord(1024, true))
      })
    })
  })

  describe('#nextInitializedTick', () => {
    it('fails if not initialized', async () => {
      await expect(TickBitmap.nextInitializedTick(0, true, -99999)).to.be.revertedWith(
        'TickMath::nextInitializedTick: no initialized next tick'
      )
      await expect(TickBitmap.nextInitializedTick(0, false, 99999)).to.be.revertedWith(
        'TickMath::nextInitializedTick: no initialized next tick'
      )
    })
    it('fails if minOrMax not in right direction', async () => {
      await expect(TickBitmap.nextInitializedTick(0, true, 1)).to.be.revertedWith(
        'TickBitmap::nextInitializedTick: minOrMax must be in the direction of lte'
      )
      await expect(TickBitmap.nextInitializedTick(0, false, 0)).to.be.revertedWith(
        'TickBitmap::nextInitializedTick: minOrMax must be in the direction of lte'
      )
    })
    it('succeeds if initialized only to the left', async () => {
      await initTicks([MIN_TICK])
      expect(await TickBitmap.nextInitializedTick(0, true, MIN_TICK)).to.eq(MIN_TICK)
      expect(await TickBitmap.nextInitializedTick(MIN_TICK + 1, true, MIN_TICK)).to.eq(MIN_TICK)
      expect(await TickBitmap.nextInitializedTick(MIN_TICK, true, MIN_TICK)).to.eq(MIN_TICK)
    })
    it('succeeds if initialized only to the right', async () => {
      await initTicks([MAX_TICK])
      expect(await TickBitmap.nextInitializedTick(0, false, MAX_TICK)).to.eq(MAX_TICK)
      expect(await TickBitmap.nextInitializedTick(MAX_TICK - 1, false, MAX_TICK)).to.eq(MAX_TICK)
    })

    describe('initialized', () => {
      beforeEach(() => initTicks([MIN_TICK, -1259, 73, 529, 2350, MAX_TICK]))
      describe('lte = false', () => {
        it('one iteration', async () => {
          expect(await TickBitmap.nextInitializedTick(480, false, MAX_TICK)).to.eq(529)
        })
        it('starting from initialized tick', async () => {
          expect(await TickBitmap.nextInitializedTick(529, false, MAX_TICK)).to.eq(2350)
          expect(await TickBitmap.nextInitializedTick(2350, false, MAX_TICK)).to.eq(MAX_TICK)
        })
        it('starting from just before initialized tick', async () => {
          expect(await TickBitmap.nextInitializedTick(72, false, MAX_TICK)).to.eq(73)
          expect(await TickBitmap.nextInitializedTick(528, false, MAX_TICK)).to.eq(529)
        })
        it('multiple iterations', async () => {
          expect(await TickBitmap.nextInitializedTick(120, false, MAX_TICK)).to.eq(529)
        })
        it('gas cost single iteration', async () => {
          await snapshotGasCost(TickBitmap.getGasCostOfNextInitializedTick(400, false, MAX_TICK))
        })
        it('gas cost many iterations', async () => {
          await snapshotGasCost(TickBitmap.getGasCostOfNextInitializedTick(2350, false, MAX_TICK))
        })
      })
      describe('lte = true', () => {
        it('one iteration', async () => {
          expect(await TickBitmap.nextInitializedTick(-1230, true, MIN_TICK)).to.eq(-1259)
        })
        it('starting from initialized tick', async () => {
          expect(await TickBitmap.nextInitializedTick(529, true, MIN_TICK)).to.eq(529)
        })
        it('getting to MIN_TICK', async () => {
          expect(await TickBitmap.nextInitializedTick(-1260, true, MIN_TICK)).to.eq(MIN_TICK)
        })
        it('multiple iterations', async () => {
          expect(await TickBitmap.nextInitializedTick(528, true, MIN_TICK)).to.eq(73)
          expect(await TickBitmap.nextInitializedTick(2349, true, MIN_TICK)).to.eq(529)
        })
        it('gas cost single iteration', async () => {
          await snapshotGasCost(TickBitmap.getGasCostOfNextInitializedTick(124, true, MIN_TICK))
        })
        it('gas cost many iterations', async () => {
          await snapshotGasCost(TickBitmap.getGasCostOfNextInitializedTick(2349, true, MIN_TICK))
        })
      })
    })
  })
})
