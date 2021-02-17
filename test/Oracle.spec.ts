import { BigNumber, BigNumberish } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { OracleTest } from '../typechain/OracleTest'
import checkObservationEquals from './shared/checkObservationEquals'
import { expect } from './shared/expect'
import { TEST_POOL_START_TIME } from './shared/fixtures'
import snapshotGasCost from './shared/snapshotGasCost'

describe('Oracle', () => {
  const [wallet, other] = waffle.provider.getWallets()

  let loadFixture: ReturnType<typeof waffle.createFixtureLoader>
  before('create fixture loader', async () => {
    loadFixture = waffle.createFixtureLoader([wallet, other])
  })

  const oracleFixture = async () => {
    const oracleTestFactory = await ethers.getContractFactory('OracleTest')
    return (await oracleTestFactory.deploy()) as OracleTest
  }

  const initializedOracleFixture = async () => {
    const oracle = await oracleFixture()
    await oracle.initialize({
      time: 0,
      tick: 0,
      liquidity: 0,
    })
    return oracle
  }

  describe('#initialize', () => {
    let oracle: OracleTest
    beforeEach('deploy test oracle', async () => {
      oracle = await loadFixture(oracleFixture)
    })
    it('index is 0', async () => {
      await oracle.initialize({ liquidity: 1, tick: 1, time: 1 })
      expect(await oracle.index()).to.eq(0)
    })
    it('cardinality is 1', async () => {
      await oracle.initialize({ liquidity: 1, tick: 1, time: 1 })
      expect(await oracle.cardinality()).to.eq(1)
    })
    it('cardinality next is 1', async () => {
      await oracle.initialize({ liquidity: 1, tick: 1, time: 1 })
      expect(await oracle.cardinalityNext()).to.eq(1)
    })
    it('sets first slot timestamp only', async () => {
      await oracle.initialize({ liquidity: 1, tick: 1, time: 1 })
      checkObservationEquals(await oracle.observations(0), {
        initialized: true,
        blockTimestamp: 1,
        tickCumulative: 0,
        liquidityCumulative: 0,
      })
    })
    it('gas', async () => {
      await snapshotGasCost(oracle.initialize({ liquidity: 1, tick: 1, time: 1 }))
    })
  })

  describe('#grow', () => {
    let oracle: OracleTest
    beforeEach('deploy initialized test oracle', async () => {
      oracle = await loadFixture(initializedOracleFixture)
    })

    it('increases the cardinality next for the first call', async () => {
      await oracle.grow(5)
      expect(await oracle.index()).to.eq(0)
      expect(await oracle.cardinality()).to.eq(1)
      expect(await oracle.cardinalityNext()).to.eq(5)
    })

    it('does not touch the first slot', async () => {
      await oracle.grow(5)
      checkObservationEquals(await oracle.observations(0), {
        liquidityCumulative: 0,
        tickCumulative: 0,
        blockTimestamp: 0,
        initialized: true,
      })
    })

    it('is no op if oracle is already gte that size', async () => {
      await oracle.grow(5)
      await oracle.grow(3)
      expect(await oracle.index()).to.eq(0)
      expect(await oracle.cardinality()).to.eq(1)
      expect(await oracle.cardinalityNext()).to.eq(5)
    })

    it('adds data to all the slots', async () => {
      await oracle.grow(5)
      for (let i = 1; i < 5; i++) {
        checkObservationEquals(await oracle.observations(i), {
          liquidityCumulative: 0,
          tickCumulative: 0,
          blockTimestamp: 1,
          initialized: false,
        })
      }
    })

    it('grow after wrap', async () => {
      await oracle.grow(2)
      await oracle.update({ advanceTimeBy: 2, liquidity: 1, tick: 1 }) // index is now 1
      await oracle.update({ advanceTimeBy: 2, liquidity: 1, tick: 1 }) // index is now 0 again
      expect(await oracle.index()).to.eq(0)
      await oracle.grow(3)
      expect(await oracle.index()).to.eq(0)
      expect(await oracle.cardinality()).to.eq(2)
      expect(await oracle.cardinalityNext()).to.eq(3)
    })

    it('gas for growing by 1 slot when index == cardinality - 1', async () => {
      await snapshotGasCost(oracle.grow(2))
    })

    it('gas for growing by 10 slots when index == cardinality - 1', async () => {
      await snapshotGasCost(oracle.grow(11))
    })

    it('gas for growing by 1 slot when index != cardinality - 1', async () => {
      await oracle.grow(2)
      await snapshotGasCost(oracle.grow(3))
    })

    it('gas for growing by 10 slots when index != cardinality - 1', async () => {
      await oracle.grow(2)
      await snapshotGasCost(oracle.grow(12))
    })
  })

  describe('#write', () => {
    let oracle: OracleTest

    beforeEach('deploy initialized test oracle', async () => {
      oracle = await loadFixture(initializedOracleFixture)
    })

    it('single element array gets overwritten', async () => {
      await oracle.update({ advanceTimeBy: 1, tick: 2, liquidity: 5 })
      expect(await oracle.index()).to.eq(0)
      checkObservationEquals(await oracle.observations(0), {
        initialized: true,
        liquidityCumulative: 0,
        tickCumulative: 0,
        blockTimestamp: 1,
      })
      await oracle.update({ advanceTimeBy: 5, tick: -1, liquidity: 8 })
      expect(await oracle.index()).to.eq(0)
      checkObservationEquals(await oracle.observations(0), {
        initialized: true,
        liquidityCumulative: 25,
        tickCumulative: 10,
        blockTimestamp: 6,
      })
      await oracle.update({ advanceTimeBy: 3, tick: 2, liquidity: 3 })
      expect(await oracle.index()).to.eq(0)
      checkObservationEquals(await oracle.observations(0), {
        initialized: true,
        liquidityCumulative: 49,
        tickCumulative: 7,
        blockTimestamp: 9,
      })
    })

    it('does nothing if time has not changed', async () => {
      await oracle.grow(2)
      await oracle.update({ advanceTimeBy: 1, tick: 3, liquidity: 2 })
      expect(await oracle.index()).to.eq(1)
      await oracle.update({ advanceTimeBy: 0, tick: -5, liquidity: 9 })
      expect(await oracle.index()).to.eq(1)
    })

    it('writes an index if time has changed', async () => {
      await oracle.grow(3)
      await oracle.update({ advanceTimeBy: 6, tick: 3, liquidity: 2 })
      expect(await oracle.index()).to.eq(1)
      await oracle.update({ advanceTimeBy: 4, tick: -5, liquidity: 9 })

      expect(await oracle.index()).to.eq(2)
      checkObservationEquals(await oracle.observations(1), {
        tickCumulative: 0,
        liquidityCumulative: 0,
        initialized: true,
        blockTimestamp: 6,
      })
    })

    it('grows cardinality when writing past', async () => {
      await oracle.grow(2)
      await oracle.grow(4)
      expect(await oracle.cardinality()).to.eq(1)
      await oracle.update({ advanceTimeBy: 3, tick: 5, liquidity: 6 })
      expect(await oracle.cardinality()).to.eq(4)
      await oracle.update({ advanceTimeBy: 4, tick: 6, liquidity: 4 })
      expect(await oracle.cardinality()).to.eq(4)
      expect(await oracle.index()).to.eq(2)
      checkObservationEquals(await oracle.observations(2), {
        liquidityCumulative: 24,
        tickCumulative: 20,
        initialized: true,
        blockTimestamp: 7,
      })
    })

    it('wraps around', async () => {
      await oracle.grow(3)
      await oracle.update({ advanceTimeBy: 3, tick: 1, liquidity: 2 })
      await oracle.update({ advanceTimeBy: 4, tick: 2, liquidity: 3 })
      await oracle.update({ advanceTimeBy: 5, tick: 3, liquidity: 4 })

      expect(await oracle.index()).to.eq(0)

      checkObservationEquals(await oracle.observations(0), {
        liquidityCumulative: 23,
        tickCumulative: 14,
        initialized: true,
        blockTimestamp: 12,
      })
    })

    it('accumulates liquidity', async () => {
      await oracle.grow(4)

      await oracle.update({ advanceTimeBy: 3, tick: 3, liquidity: 2 })
      await oracle.update({ advanceTimeBy: 4, tick: -7, liquidity: 6 })
      await oracle.update({ advanceTimeBy: 5, tick: -2, liquidity: 4 })

      expect(await oracle.index()).to.eq(3)

      checkObservationEquals(await oracle.observations(1), {
        initialized: true,
        tickCumulative: 0,
        liquidityCumulative: 0,
        blockTimestamp: 3,
      })
      checkObservationEquals(await oracle.observations(2), {
        initialized: true,
        tickCumulative: 12,
        liquidityCumulative: 8,
        blockTimestamp: 7,
      })
      checkObservationEquals(await oracle.observations(3), {
        initialized: true,
        tickCumulative: -23,
        liquidityCumulative: 38,
        blockTimestamp: 12,
      })
      checkObservationEquals(await oracle.observations(4), {
        initialized: false,
        tickCumulative: 0,
        liquidityCumulative: 0,
        blockTimestamp: 0,
      })
    })
  })

  describe('#observe', () => {
    describe('before initialization', async () => {
      let oracle: OracleTest
      beforeEach('deploy test oracle', async () => {
        oracle = await loadFixture(oracleFixture)
      })

      const observeSingle = async (secondsAgo: number) => {
        const {
          tickCumulatives: [tickCumulative],
          liquidityCumulatives: [liquidityCumulative],
        } = await oracle.observe([secondsAgo])
        return { liquidityCumulative, tickCumulative }
      }

      it('fails before initialize', async () => {
        await expect(observeSingle(0)).to.be.revertedWith('I')
      })

      it('fails if an older observation does not exist', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 5 })
        await expect(observeSingle(1)).to.be.revertedWith('OLD')
      })

      it('does not fail across overflow boundary', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 2 ** 32 - 1 })
        await oracle.advanceTime(2)
        const { tickCumulative, liquidityCumulative } = await observeSingle(1)
        expect(tickCumulative).to.be.eq(2)
        expect(liquidityCumulative).to.be.eq(4)
      })

      it('single observation at current time', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 5 })
        const { tickCumulative, liquidityCumulative } = await observeSingle(0)
        expect(tickCumulative).to.eq(0)
        expect(liquidityCumulative).to.eq(0)
      })

      it('single observation in past but not earlier than secondsAgo', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 5 })
        await oracle.advanceTime(3)
        await expect(observeSingle(4)).to.be.revertedWith('OLD')
      })

      it('single observation in past at exactly seconds ago', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 5 })
        await oracle.advanceTime(3)
        const { tickCumulative, liquidityCumulative } = await observeSingle(3)
        expect(tickCumulative).to.eq(0)
        expect(liquidityCumulative).to.eq(0)
      })

      it('single observation in past counterfactual in past', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 5 })
        await oracle.advanceTime(3)
        const { tickCumulative, liquidityCumulative } = await observeSingle(1)
        expect(tickCumulative).to.eq(4)
        expect(liquidityCumulative).to.eq(8)
      })

      it('single observation in past counterfactual now', async () => {
        await oracle.initialize({ liquidity: 4, tick: 2, time: 5 })
        await oracle.advanceTime(3)
        const { tickCumulative, liquidityCumulative } = await observeSingle(0)
        expect(tickCumulative).to.eq(6)
        expect(liquidityCumulative).to.eq(12)
      })

      it('two observations in chronological order 0 seconds ago exact', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
        const { tickCumulative, liquidityCumulative } = await observeSingle(0)
        expect(tickCumulative).to.eq(-20)
        expect(liquidityCumulative).to.eq(20)
      })

      it('two observations in chronological order 0 seconds ago counterfactual', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
        await oracle.advanceTime(7)
        const { tickCumulative, liquidityCumulative } = await observeSingle(0)
        expect(tickCumulative).to.eq(-13)
        expect(liquidityCumulative).to.eq(34)
      })

      it('two observations in chronological order seconds ago is exactly on first observation', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
        await oracle.advanceTime(7)
        const { tickCumulative, liquidityCumulative } = await observeSingle(11)
        expect(tickCumulative).to.eq(0)
        expect(liquidityCumulative).to.eq(0)
      })

      it('two observations in chronological order seconds ago is between first and second', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
        await oracle.advanceTime(7)
        const { tickCumulative, liquidityCumulative } = await observeSingle(9)
        expect(tickCumulative).to.eq(-10)
        expect(liquidityCumulative).to.eq(10)
      })

      it('two observations in reverse order 0 seconds ago exact', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
        await oracle.update({ advanceTimeBy: 3, tick: -5, liquidity: 4 })
        const { tickCumulative, liquidityCumulative } = await observeSingle(0)
        expect(tickCumulative).to.eq(-17)
        expect(liquidityCumulative).to.eq(26)
      })

      it('two observations in reverse order 0 seconds ago counterfactual', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
        await oracle.update({ advanceTimeBy: 3, tick: -5, liquidity: 4 })
        await oracle.advanceTime(7)
        const { tickCumulative, liquidityCumulative } = await observeSingle(0)
        expect(tickCumulative).to.eq(-52)
        expect(liquidityCumulative).to.eq(54)
      })

      it('two observations in reverse order seconds ago is exactly on first observation', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
        await oracle.update({ advanceTimeBy: 3, tick: -5, liquidity: 4 })
        await oracle.advanceTime(7)
        const { tickCumulative, liquidityCumulative } = await observeSingle(10)
        expect(tickCumulative).to.eq(-20)
        expect(liquidityCumulative).to.eq(20)
      })

      it('two observations in reverse order seconds ago is between first and second', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.grow(2)
        await oracle.update({ advanceTimeBy: 4, tick: 1, liquidity: 2 })
        await oracle.update({ advanceTimeBy: 3, tick: -5, liquidity: 4 })
        await oracle.advanceTime(7)
        const { tickCumulative, liquidityCumulative } = await observeSingle(9)
        expect(tickCumulative).to.eq(-19)
        expect(liquidityCumulative).to.eq(22)
      })

      it('can fetch multiple observations', async () => {
        await oracle.initialize({ time: 5, tick: 2, liquidity: BigNumber.from(2).pow(15) })
        await oracle.grow(4)
        await oracle.update({ advanceTimeBy: 13, tick: 6, liquidity: BigNumber.from(2).pow(12) })
        await oracle.advanceTime(5)

        const { tickCumulatives, liquidityCumulatives } = await oracle.observe([0, 3, 8, 13, 15, 18])
        expect(tickCumulatives).to.have.lengthOf(6)
        expect(tickCumulatives[0]).to.eq(56)
        expect(tickCumulatives[1]).to.eq(38)
        expect(tickCumulatives[2]).to.eq(20)
        expect(tickCumulatives[3]).to.eq(10)
        expect(tickCumulatives[4]).to.eq(6)
        expect(tickCumulatives[5]).to.eq(0)
        expect(liquidityCumulatives).to.have.lengthOf(6)
        expect(liquidityCumulatives[0]).to.eq(BigNumber.from(2).pow(15).mul(13).add(BigNumber.from(2).pow(12).mul(5)))
        expect(liquidityCumulatives[1]).to.eq(BigNumber.from(2).pow(15).mul(13).add(BigNumber.from(2).pow(12).mul(2)))
        expect(liquidityCumulatives[2]).to.eq(BigNumber.from(2).pow(15).mul(10))
        expect(liquidityCumulatives[3]).to.eq(BigNumber.from(2).pow(15).mul(5))
        expect(liquidityCumulatives[4]).to.eq(BigNumber.from(2).pow(15).mul(3))
        expect(liquidityCumulatives[5]).to.eq(0)
      })

      it('gas for observe since most recent', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.advanceTime(2)
        await snapshotGasCost(oracle.getGasCostOfObserve([1]))
      })

      it('gas for single observation at current time', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await snapshotGasCost(oracle.getGasCostOfObserve([0]))
      })

      it('gas for single observation at current time counterfactually computed', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
        await oracle.advanceTime(5)
        await snapshotGasCost(oracle.getGasCostOfObserve([0]))
      })
    })

    for (const startingTime of [5, 2 ** 32 - 5]) {
      describe(`initialized with 5 observations with starting time of ${startingTime}`, () => {
        const oracleFixture5Observations = async () => {
          const oracle = await oracleFixture()
          await oracle.initialize({ liquidity: 5, tick: -5, time: startingTime })
          await oracle.grow(5)
          await oracle.update({ advanceTimeBy: 3, tick: 1, liquidity: 2 })
          await oracle.update({ advanceTimeBy: 2, tick: -6, liquidity: 4 })
          await oracle.update({ advanceTimeBy: 4, tick: -2, liquidity: 4 })
          await oracle.update({ advanceTimeBy: 1, tick: -2, liquidity: 9 })
          await oracle.update({ advanceTimeBy: 3, tick: 4, liquidity: 2 })
          await oracle.update({ advanceTimeBy: 6, tick: 6, liquidity: 7 })
          return oracle
        }
        let oracle: OracleTest
        beforeEach('set up observations', async () => {
          oracle = await loadFixture(oracleFixture5Observations)
        })

        const observeSingle = async (secondsAgo: number) => {
          const {
            tickCumulatives: [tickCumulative],
            liquidityCumulatives: [liquidityCumulative],
          } = await oracle.observe([secondsAgo])
          return { liquidityCumulative, tickCumulative }
        }

        it('index, cardinality, cardinality next', async () => {
          expect(await oracle.index()).to.eq(1)
          expect(await oracle.cardinality()).to.eq(5)
          expect(await oracle.cardinalityNext()).to.eq(5)
        })
        it('latest observation same time as latest', async () => {
          const { tickCumulative, liquidityCumulative } = await observeSingle(0)
          expect(tickCumulative).to.eq(-21)
          expect(liquidityCumulative).to.eq(78)
        })
        it('latest observation 5 seconds after latest', async () => {
          await oracle.advanceTime(5)
          const { tickCumulative, liquidityCumulative } = await observeSingle(5)
          expect(tickCumulative).to.eq(-21)
          expect(liquidityCumulative).to.eq(78)
        })
        it('current observation 5 seconds after latest', async () => {
          await oracle.advanceTime(5)
          const { tickCumulative, liquidityCumulative } = await observeSingle(0)
          expect(tickCumulative).to.eq(9)
          expect(liquidityCumulative).to.eq(113)
        })
        it('between latest observation and just before latest observation at same time as latest', async () => {
          const { tickCumulative, liquidityCumulative } = await observeSingle(3)
          expect(tickCumulative).to.eq(-33)
          expect(liquidityCumulative).to.eq(72)
        })
        it('between latest observation and just before latest observation after the latest observation', async () => {
          await oracle.advanceTime(5)
          const { tickCumulative, liquidityCumulative } = await observeSingle(8)
          expect(tickCumulative).to.eq(-33)
          expect(liquidityCumulative).to.eq(72)
        })
        it('older than oldest reverts', async () => {
          await expect(observeSingle(15)).to.be.revertedWith('OLD')
          await oracle.advanceTime(5)
          await expect(observeSingle(20)).to.be.revertedWith('OLD')
        })
        it('oldest observation', async () => {
          const { tickCumulative, liquidityCumulative } = await observeSingle(14)
          expect(tickCumulative).to.eq(-13)
          expect(liquidityCumulative).to.eq(19)
        })
        it('oldest observation after some time', async () => {
          await oracle.advanceTime(6)
          const { tickCumulative, liquidityCumulative } = await observeSingle(20)
          expect(tickCumulative).to.eq(-13)
          expect(liquidityCumulative).to.eq(19)
        })

        it('fetch many values', async () => {
          await oracle.advanceTime(6)
          const { tickCumulatives, liquidityCumulatives } = await oracle.observe([20, 17, 13, 10, 5, 1, 0])
          expect({
            tickCumulatives: tickCumulatives.map((tc) => tc.toNumber()),
            liquidityCumulatives: liquidityCumulatives.map((lc) => lc.toNumber()),
          }).to.matchSnapshot()
        })

        it('gas all of last 20 seconds', async () => {
          await oracle.advanceTime(6)
          await snapshotGasCost(
            oracle.getGasCostOfObserve([20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0])
          )
        })

        it('gas latest equal', async () => {
          await snapshotGasCost(oracle.getGasCostOfObserve([0]))
        })
        it('gas latest transform', async () => {
          await oracle.advanceTime(5)
          await snapshotGasCost(oracle.getGasCostOfObserve([0]))
        })
        it('gas oldest', async () => {
          await snapshotGasCost(oracle.getGasCostOfObserve([14]))
        })
        it('gas between oldest and oldest + 1', async () => {
          await snapshotGasCost(oracle.getGasCostOfObserve([13]))
        })
        it('gas middle', async () => {
          await snapshotGasCost(oracle.getGasCostOfObserve([5]))
        })
      })
    }
  })

  describe.skip('full oracle', function () {
    this.timeout(1_200_000)

    let oracle: OracleTest

    const BATCH_SIZE = 300

    const STARTING_TIME = TEST_POOL_START_TIME

    const maxedOutOracleFixture = async () => {
      const oracle = await oracleFixture()
      await oracle.initialize({ liquidity: 0, tick: 0, time: STARTING_TIME })
      let cardinalityNext = await oracle.cardinalityNext()
      while (cardinalityNext < 65535) {
        const growTo = Math.min(65535, cardinalityNext + BATCH_SIZE)
        console.log('growing from', cardinalityNext, 'to', growTo)
        await oracle.grow(growTo)
        cardinalityNext = growTo
      }

      for (let i = 0; i < 65535; i += BATCH_SIZE) {
        console.log('batch update starting at', i)
        const batch = Array(BATCH_SIZE)
          .fill(null)
          .map((_, j) => ({
            advanceTimeBy: 13,
            tick: -i - j,
            liquidity: i + j,
          }))
        await oracle.batchUpdate(batch)
      }

      return oracle
    }

    beforeEach('create a full oracle', async () => {
      oracle = await loadFixture(maxedOutOracleFixture)
    })

    it('has max cardinality next', async () => {
      expect(await oracle.cardinalityNext()).to.eq(65535)
    })

    it('has max cardinality', async () => {
      expect(await oracle.cardinality()).to.eq(65535)
    })

    it('index wrapped around', async () => {
      expect(await oracle.index()).to.eq(165)
    })

    async function checkObserve(
      secondsAgo: number,
      expected?: { tickCumulative: BigNumberish; liquidityCumulative: BigNumberish }
    ) {
      const { tickCumulatives, liquidityCumulatives } = await oracle.observe([secondsAgo])
      const check = {
        tickCumulative: tickCumulatives[0].toString(),
        liquidityCumulative: liquidityCumulatives[0].toString(),
      }
      if (typeof expected === 'undefined') {
        expect(check).to.matchSnapshot()
      } else {
        expect(check).to.deep.eq({
          tickCumulative: expected.tickCumulative.toString(),
          liquidityCumulative: expected.liquidityCumulative.toString(),
        })
      }
    }

    it('can observe into the ordered portion with exact seconds ago', async () => {
      await checkObserve(100 * 13, {
        liquidityCumulative: '27970560813',
        tickCumulative: '-27970560813',
      })
    })

    it('can observe into the ordered portion with unexact seconds ago', async () => {
      await checkObserve(100 * 13 + 5, {
        liquidityCumulative: '27970232823',
        tickCumulative: '-27970232823',
      })
    })

    it('can observe at exactly the latest observation', async () => {
      await checkObserve(0, {
        liquidityCumulative: '28055903863',
        tickCumulative: '-28055903863',
      })
    })

    it('can observe at exactly the latest observation after some time passes', async () => {
      await oracle.advanceTime(5)
      await checkObserve(5, {
        liquidityCumulative: '28055903863',
        tickCumulative: '-28055903863',
      })
    })

    it('can observe after the latest observation counterfactual', async () => {
      await oracle.advanceTime(5)
      await checkObserve(3, {
        liquidityCumulative: '28056035261',
        tickCumulative: '-28056035261',
      })
    })

    it('can observe into the unordered portion of array at exact seconds ago of observation', async () => {
      await checkObserve(200 * 13, {
        liquidityCumulative: '27885347763',
        tickCumulative: '-27885347763',
      })
    })

    it('can observe into the unordered portion of array at seconds ago between observations', async () => {
      await checkObserve(200 * 13 + 5, {
        liquidityCumulative: '27885020273',
        tickCumulative: '-27885020273',
      })
    })

    it('can observe the oldest observation 13*65534 seconds ago', async () => {
      await checkObserve(13 * 65534, {
        liquidityCumulative: '175890',
        tickCumulative: '-175890',
      })
    })

    it('can observe the oldest observation 13*65534 + 5 seconds ago if time has elapsed', async () => {
      await oracle.advanceTime(5)
      await checkObserve(13 * 65534 + 5, {
        liquidityCumulative: '175890',
        tickCumulative: '-175890',
      })
    })

    it('gas cost of observe(0)', async () => {
      await snapshotGasCost(oracle.getGasCostOfObserve([0]))
    })
    it('gas cost of observe(200 * 13)', async () => {
      await snapshotGasCost(oracle.getGasCostOfObserve([200 + 13]))
    })
    it('gas cost of observe(200 * 13 + 5)', async () => {
      await snapshotGasCost(oracle.getGasCostOfObserve([200 + 13 + 5]))
    })
    it('gas cost of observe(0) after 5 seconds', async () => {
      await oracle.advanceTime(5)
      await snapshotGasCost(oracle.getGasCostOfObserve([0]))
    })
    it('gas cost of observe(5) after 5 seconds', async () => {
      await oracle.advanceTime(5)
      await snapshotGasCost(oracle.getGasCostOfObserve([5]))
    })
    it('gas cost of observe(oldest)', async () => {
      await snapshotGasCost(oracle.getGasCostOfObserve([65534 * 13]))
    })
    it('gas cost of observe(oldest) after 5 seconds', async () => {
      await oracle.advanceTime(5)
      await snapshotGasCost(oracle.getGasCostOfObserve([65534 * 13 + 5]))
    })
  })
})
