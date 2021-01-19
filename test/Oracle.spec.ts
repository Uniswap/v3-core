import { ethers, waffle } from 'hardhat'
import { OracleTest } from '../typechain/OracleTest'
import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'

function getSecondsAgo(then: number, now: number) {
  const result = now >= then ? now - then : now + 2 ** 32 - then
  return result % 2 ** 32
}

async function checkObservation(
  oracle: OracleTest,
  index: number,
  observation: {
    tickCumulative: number
    liquidityCumulative: number
    initialized: boolean
    blockTimestamp: number
  }
) {
  const { tickCumulative, liquidityCumulative, initialized, blockTimestamp } = await oracle.observations(index)
  expect(
    {
      initialized,
      blockTimestamp,
      tickCumulative: tickCumulative.toNumber(),
      liquidityCumulative: liquidityCumulative.toNumber(),
    },
    `observation index ${index} is equivalent`
  ).to.deep.eq(observation)
}

describe.only('Oracle', () => {
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
    it('target is 1', async () => {
      await oracle.initialize({ liquidity: 1, tick: 1, time: 1 })
      expect(await oracle.target()).to.eq(1)
    })
    it('sets first slot timestamp only', async () => {
      await oracle.initialize({ liquidity: 1, tick: 1, time: 1 })
      await checkObservation(oracle, 0, {
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

    it('increases the cardinality and target for the first call', async () => {
      await oracle.grow(5)
      expect(await oracle.index()).to.eq(0)
      expect(await oracle.cardinality()).to.eq(5)
      expect(await oracle.target()).to.eq(5)
    })

    it('does not touch the first slot', async () => {
      await oracle.grow(5)
      await checkObservation(oracle, 0, {
        liquidityCumulative: 0,
        tickCumulative: 0,
        blockTimestamp: 0,
        initialized: true,
      })
    })

    it('adds data to all the slots', async () => {
      await oracle.grow(5)
      for (let i = 1; i < 5; i++) {
        await checkObservation(oracle, i, {
          liquidityCumulative: 0,
          tickCumulative: 0,
          blockTimestamp: 1,
          initialized: false,
        })
      }
    })

    it('does not change the target when index != cardinality - 1', async () => {
      await oracle.grow(2)
      await oracle.grow(5)
      expect(await oracle.cardinality()).to.eq(2)
      expect(await oracle.target()).to.eq(5)
    })

    it('grow after wrap', async () => {
      await oracle.grow(2)
      await oracle.update({ advanceTimeBy: 2, liquidity: 1, tick: 1 }) // index is now 1
      await oracle.update({ advanceTimeBy: 2, liquidity: 1, tick: 1 }) // index is now 0 again
      expect(await oracle.index()).to.eq(0)
      await oracle.grow(3)
      expect(await oracle.index()).to.eq(0)
      expect(await oracle.cardinality()).to.eq(2)
      expect(await oracle.target()).to.eq(3)
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
      await checkObservation(oracle, 0, {
        initialized: true,
        liquidityCumulative: 0,
        tickCumulative: 0,
        blockTimestamp: 1,
      })
      await oracle.update({ advanceTimeBy: 5, tick: -1, liquidity: 8 })
      expect(await oracle.index()).to.eq(0)
      await checkObservation(oracle, 0, {
        initialized: true,
        liquidityCumulative: 25,
        tickCumulative: 10,
        blockTimestamp: 6,
      })
      await oracle.update({ advanceTimeBy: 3, tick: 2, liquidity: 3 })
      expect(await oracle.index()).to.eq(0)
      await checkObservation(oracle, 0, {
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
      await checkObservation(oracle, 1, {
        tickCumulative: 0,
        liquidityCumulative: 0,
        initialized: true,
        blockTimestamp: 6,
      })
    })

    it('accumulates liquidity', async () => {
      await oracle.grow(4)

      await oracle.update({ advanceTimeBy: 3, tick: 3, liquidity: 2 })
      await oracle.update({ advanceTimeBy: 4, tick: -7, liquidity: 6 })
      await oracle.update({ advanceTimeBy: 5, tick: -2, liquidity: 4 })

      expect(await oracle.index()).to.eq(3)

      await checkObservation(oracle, 1, {
        initialized: true,
        tickCumulative: 0,
        liquidityCumulative: 0,
        blockTimestamp: 3,
      })
      await checkObservation(oracle, 2, {
        initialized: true,
        tickCumulative: 12,
        liquidityCumulative: 8,
        blockTimestamp: 7,
      })
      await checkObservation(oracle, 3, {
        initialized: true,
        tickCumulative: -23,
        liquidityCumulative: 38,
        blockTimestamp: 12,
      })
      await checkObservation(oracle, 4, {
        initialized: false,
        tickCumulative: 0,
        liquidityCumulative: 0,
        blockTimestamp: 0,
      })
    })
  })

  describe('#scry', () => {
    let oracle: OracleTest
    beforeEach('deploy test oracle', async () => {
      oracle = await loadFixture(oracleFixture)
    })

    it('fails before initialize', async () => {
      await expect(oracle.scry(0)).to.be.revertedWith('')
    })

    // it('fails for single observation without any older time', async () => {
    //   await oracle.initialize({ liquidity: 1, tick: 2, time: 5 })
    //   await expect(oracle.scry(0)).to.be.revertedWith('OLD')
    // })

    describe('after initialize', () => {
      beforeEach('initialize', async () => {
        await oracle.initialize({ liquidity: 5, tick: -5, time: 5 })
      })

      it('works if current second has observation', async () => {
        await oracle.update({ advanceTimeBy: 1, tick: 1, liquidity: 2 })
        const { tickCumulative, liquidityCumulative } = await oracle.scry(0)

        // expect(tickCumulative).to.eq(0)
        // expect(liquidityCumulative).to.eq(2)
      })

      //   describe('monotonic observations, shifted', () => {})
      //
      //   describe('monotonic observations, unshifted', () => {})
      //
      //   describe('non-monotonic observations, unshifted', () => {})
      //
      //   describe('non-monotonic observations, shifted', () => {})
    })
  })
})
