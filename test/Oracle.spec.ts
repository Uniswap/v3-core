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
      await checkObservation(oracle, 0, {
        initialized: true,
        liquidityCumulative: 0,
        tickCumulative: 0,
        blockTimestamp: 1,
      })
      await oracle.update({ advanceTimeBy: 5, tick: -1, liquidity: 8 })
      await checkObservation(oracle, 0, {
        initialized: true,
        liquidityCumulative: 25,
        tickCumulative: 10,
        blockTimestamp: 6,
      })
      await oracle.update({ advanceTimeBy: 3, tick: 2, liquidity: 3 })
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

  // describe('#scry', () => {
  //   describe('clean state tests', () => {
  //     let oracle: OracleTest
  //     beforeEach('deploy test oracle', async () => {
  //       oracle = await loadFixture(oracleFixture)
  //     })
  //
  //     describe('advancing cardinality target', () => {
  //       // TODO add more test cases here
  //       it('simple advance successful', async () => {
  //         await setOracle(
  //           oracle,
  //           [
  //             {
  //               blockTimestamp: 0,
  //               tickCumulative: 0,
  //               liquidityCumulative: 0,
  //               initialized: true,
  //             },
  //           ],
  //           0,
  //           13,
  //           2,
  //           3,
  //           1,
  //           1
  //         )
  //
  //         await oracle.write(5, 5)
  //
  //         const observation = await oracle.observations(0)
  //         expect(observation.blockTimestamp).to.be.eq(13)
  //         expect(observation.tickCumulative).to.be.eq(26)
  //         expect(observation.liquidityCumulative).to.be.eq(39)
  //         expect(observation.initialized).to.be.true
  //
  //         await setOracle(
  //           oracle,
  //           [
  //             {
  //               blockTimestamp: 13,
  //               tickCumulative: 26,
  //               liquidityCumulative: 39,
  //               initialized: true,
  //             },
  //           ],
  //           0,
  //           14,
  //           5,
  //           5,
  //           1,
  //           2
  //         )
  //
  //         await oracle.write(5, 5)
  //
  //         const observation0 = await oracle.observations(0)
  //         expect(observation0).to.containSubset(observation)
  //
  //         const observation1 = await oracle.observations(1)
  //         expect(observation1.blockTimestamp).to.be.eq(14)
  //         expect(observation1.tickCumulative).to.be.eq(31)
  //         expect(observation1.liquidityCumulative).to.be.eq(44)
  //         expect(observation1.initialized).to.be.true
  //       })
  //     })
  //
  //     describe('failures', () => {
  //       // TODO this doesn't work anymore because we initialize in the constructor
  //       // it('fails while uninitialized', async () => {
  //       //   await expect(oracle.scry(0)).to.be.revertedWith('UI')
  //       // })
  //
  //       it('fails for single observation without any intervening time', async () => {
  //         await setOracle(
  //           oracle,
  //           [
  //             {
  //               blockTimestamp: 0,
  //               tickCumulative: 0,
  //               liquidityCumulative: 0,
  //               initialized: true,
  //             },
  //           ],
  //           0
  //         )
  //         await expect(oracle.scry(0)).to.be.revertedWith('OLD')
  //       })
  //     })
  //
  //     describe('successes', () => {
  //       const tick = 123
  //       const liquidity = 456
  //
  //       it('timestamp equal to the most recent observation', async () => {
  //         await setOracle(
  //           oracle,
  //           [
  //             {
  //               blockTimestamp: 0,
  //               tickCumulative: 0,
  //               liquidityCumulative: 0,
  //               initialized: true,
  //             },
  //             {
  //               blockTimestamp: 1,
  //               tickCumulative: tick,
  //               liquidityCumulative: liquidity,
  //               initialized: true,
  //             },
  //           ],
  //           1,
  //           1
  //         )
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(0)
  //
  //         expect(tickCumulative).to.be.eq(tick)
  //         expect(liquidityCumulative).to.be.eq(liquidity)
  //       })
  //
  //       it('timestamp greater than the most recent observation', async () => {
  //         await setOracle(
  //           oracle,
  //           [
  //             {
  //               blockTimestamp: 0,
  //               tickCumulative: 0,
  //               liquidityCumulative: 0,
  //               initialized: true,
  //             },
  //           ],
  //           0,
  //           2,
  //           tick,
  //           liquidity
  //         )
  //
  //         let { tickCumulative, liquidityCumulative } = await oracle.scry(1)
  //         expect(tickCumulative).to.be.eq(tick)
  //         expect(liquidityCumulative).to.be.eq(liquidity)
  //         ;({ tickCumulative, liquidityCumulative } = await oracle.scry(0))
  //         expect(tickCumulative).to.be.eq(tick * 2)
  //         expect(liquidityCumulative).to.be.eq(liquidity * 2)
  //       })
  //
  //       it('worst-case binary search', async () => {
  //         await setOracle(
  //           oracle,
  //           [
  //             {
  //               blockTimestamp: 0,
  //               tickCumulative: 0,
  //               liquidityCumulative: 0,
  //               initialized: true,
  //             },
  //             {
  //               blockTimestamp: 2,
  //               tickCumulative: tick * 2,
  //               liquidityCumulative: liquidity * 2,
  //               initialized: true,
  //             },
  //           ],
  //           1,
  //           2,
  //           tick,
  //           liquidity
  //         )
  //
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(1)
  //
  //         expect(tickCumulative).to.be.eq(tick)
  //         expect(liquidityCumulative).to.be.eq(liquidity)
  //       })
  //     })
  //
  //     describe('gas', () => {
  //       it('timestamp equal to the most recent observation', async () => {
  //         await setOracle(
  //           oracle,
  //           [
  //             {
  //               blockTimestamp: 0,
  //               tickCumulative: 0,
  //               liquidityCumulative: 0,
  //               initialized: true,
  //             },
  //             {
  //               blockTimestamp: 1,
  //               tickCumulative: 0,
  //               liquidityCumulative: 0,
  //               initialized: true,
  //             },
  //           ],
  //           1,
  //           1
  //         )
  //         await snapshotGasCost(oracle.getGasCostOfScry(0))
  //       })
  //
  //       it('timestamp greater than the most recent observation', async () => {
  //         await setOracle(
  //           oracle,
  //           [
  //             {
  //               blockTimestamp: 0,
  //               tickCumulative: 0,
  //               liquidityCumulative: 0,
  //               initialized: true,
  //             },
  //           ],
  //           0,
  //           1
  //         )
  //         await snapshotGasCost(oracle.getGasCostOfScry(0))
  //       })
  //
  //       it('worst-case binary search', async () => {
  //         await setOracle(
  //           oracle,
  //           [
  //             {
  //               blockTimestamp: 0,
  //               tickCumulative: 0,
  //               liquidityCumulative: 0,
  //               initialized: true,
  //             },
  //             {
  //               blockTimestamp: 2,
  //               tickCumulative: 0,
  //               liquidityCumulative: 0,
  //               initialized: true,
  //             },
  //           ],
  //           1,
  //           2
  //         )
  //         await snapshotGasCost(oracle.getGasCostOfScry(1))
  //       })
  //     })
  //   })
  //
  //   describe('full cases', () => {
  //     const timestampDelta = 13
  //     const ticks = new Array(CARDINALITY).fill(0).map((_, i) => i * 3)
  //     const liquidities = new Array(CARDINALITY).fill(0).map((_, i) => i * 4)
  //
  //     const tick = 123
  //     const liquidity = 456
  //
  //     describe('monotonic observations, unshifted', () => {
  //       const observations = getDefaultObservations()
  //
  //       for (let i = 0; i < observations.length; i++) {
  //         observations[i].initialized = true
  //         if (i === 0) continue
  //
  //         const last = observations[i - 1]
  //
  //         observations[i].blockTimestamp = (last.blockTimestamp + timestampDelta) % 2 ** 32
  //         observations[i].tickCumulative = last.tickCumulative + ticks[i] * timestampDelta
  //         observations[i].liquidityCumulative = last.liquidityCumulative + liquidities[i] * timestampDelta
  //       }
  //
  //       const oldestIndex = 0
  //       const newestIndex = observations.length - 1
  //
  //       const now = observations[newestIndex].blockTimestamp + 1
  //
  //       const observationsFixture = async () => {
  //         const oracle = await oracleFixture()
  //         await setOracle(oracle, observations, newestIndex, now, tick, liquidity)
  //         return oracle
  //       }
  //
  //       let oracle: OracleTest
  //       beforeEach('set the oracle', async () => {
  //         oracle = await loadFixture(observationsFixture)
  //       })
  //
  //       it('works for +1', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 1, now)
  //         )
  //         expect(tickCumulative).to.be.eq(ticks[1] * 1)
  //         expect(liquidityCumulative).to.be.eq(liquidities[1] * 1)
  //       })
  //       it('works for +2', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 2, now)
  //         )
  //         expect(tickCumulative).to.be.eq(ticks[1] * 2)
  //         expect(liquidityCumulative).to.be.eq(liquidities[1] * 2)
  //       })
  //
  //       it('works for +13', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 13, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[1].tickCumulative)
  //         expect(liquidityCumulative).to.be.eq(observations[1].liquidityCumulative)
  //       })
  //       it('works for +14', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 14, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[1].tickCumulative + ticks[2])
  //         expect(liquidityCumulative).to.be.eq(observations[1].liquidityCumulative + liquidities[2])
  //       })
  //
  //       it('works for +6655', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 6655, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[511].tickCumulative + ticks[512] * 12)
  //         expect(liquidityCumulative).to.be.eq(observations[511].liquidityCumulative + liquidities[512] * 12)
  //       })
  //       it('works for +6656', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 6656, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[512].tickCumulative)
  //         expect(liquidityCumulative).to.be.eq(observations[512].liquidityCumulative)
  //       })
  //       it('works for +6657', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 6657, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[512].tickCumulative + ticks[513])
  //         expect(liquidityCumulative).to.be.eq(observations[512].liquidityCumulative + liquidities[513])
  //       })
  //
  //       it('works for -2', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(2)
  //         expect(tickCumulative).to.be.eq(observations[newestIndex - 1].tickCumulative + ticks[1023] * 12)
  //         expect(liquidityCumulative).to.be.eq(
  //           observations[newestIndex - 1].liquidityCumulative + liquidities[1023] * 12
  //         )
  //       })
  //       it('works for -1', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(1)
  //         expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative)
  //         expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative)
  //       })
  //       it('works for 0', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(0)
  //         expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative + tick)
  //         expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative + liquidity)
  //       })
  //     })
  //
  //     describe('monotonic observations, shifted', () => {
  //       const observations = getDefaultObservations()
  //
  //       for (let i = 0; i < observations.length; i++) {
  //         observations[i].initialized = true
  //         if (i === 0) continue
  //
  //         const last = observations[i - 1]
  //
  //         observations[i].blockTimestamp = (last.blockTimestamp + timestampDelta) % 2 ** 32
  //         observations[i].tickCumulative = last.tickCumulative + ticks[i] * timestampDelta
  //         observations[i].liquidityCumulative = last.liquidityCumulative + liquidities[i] * timestampDelta
  //       }
  //
  //       for (let i = 0; i < 100; i++) {
  //         observations.push(observations.shift()!)
  //       }
  //
  //       const oldestIndex = 924
  //       const newestIndex = 923
  //
  //       const now = observations[newestIndex].blockTimestamp + 1
  //
  //       const observationsFixture = async () => {
  //         const oracle = await oracleFixture()
  //         await setOracle(oracle, observations, newestIndex, now, tick, liquidity)
  //         return oracle
  //       }
  //
  //       let oracle: OracleTest
  //       beforeEach('set the oracle', async () => {
  //         oracle = await loadFixture(observationsFixture)
  //       })
  //
  //       it('works for +1', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 1, now)
  //         )
  //         expect(tickCumulative).to.be.eq(ticks[1] * 1)
  //         expect(liquidityCumulative).to.be.eq(liquidities[1] * 1)
  //       })
  //       it('works for +2', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 2, now)
  //         )
  //         expect(tickCumulative).to.be.eq(ticks[1] * 2)
  //         expect(liquidityCumulative).to.be.eq(liquidities[1] * 2)
  //       })
  //
  //       it('works for +13', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 13, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[oldestIndex + 1].tickCumulative)
  //         expect(liquidityCumulative).to.be.eq(observations[oldestIndex + 1].liquidityCumulative)
  //       })
  //       it('works for +14', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 14, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[oldestIndex + 1].tickCumulative + ticks[2])
  //         expect(liquidityCumulative).to.be.eq(observations[oldestIndex + 1].liquidityCumulative + liquidities[2])
  //       })
  //
  //       it('works for +6655', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 6655, now)
  //         )
  //         expect(tickCumulative).to.be.eq(
  //           observations[(oldestIndex + 511) % CARDINALITY].tickCumulative + ticks[512] * 12
  //         )
  //         expect(liquidityCumulative).to.be.eq(
  //           observations[(oldestIndex + 511) % CARDINALITY].liquidityCumulative + liquidities[512] * 12
  //         )
  //       })
  //       it('works for +6656', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 6656, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[(oldestIndex + 512) % CARDINALITY].tickCumulative)
  //         expect(liquidityCumulative).to.be.eq(observations[(oldestIndex + 512) % CARDINALITY].liquidityCumulative)
  //       })
  //       it('works for +6657', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 6657, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[(oldestIndex + 512) % CARDINALITY].tickCumulative + ticks[513])
  //         expect(liquidityCumulative).to.be.eq(
  //           observations[(oldestIndex + 512) % CARDINALITY].liquidityCumulative + liquidities[513]
  //         )
  //       })
  //
  //       it('works for -2', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(2)
  //         expect(tickCumulative).to.be.eq(observations[newestIndex - 1].tickCumulative + ticks[1023] * 12)
  //         expect(liquidityCumulative).to.be.eq(
  //           observations[newestIndex - 1].liquidityCumulative + liquidities[1023] * 12
  //         )
  //       })
  //       it('works for -1', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(1)
  //         expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative)
  //         expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative)
  //       })
  //       it('works for 0', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(0)
  //         expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative + tick)
  //         expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative + liquidity)
  //       })
  //     })
  //
  //     describe('non-monotonic observations, unshifted', () => {
  //       const start = 4294964297
  //
  //       const observations = getDefaultObservations()
  //
  //       for (let i = 0; i < observations.length; i++) {
  //         observations[i].initialized = true
  //         if (i === 0) {
  //           observations[i].blockTimestamp = start
  //           continue
  //         }
  //
  //         const last = observations[i - 1]
  //
  //         observations[i].blockTimestamp = (last.blockTimestamp + timestampDelta) % 2 ** 32
  //         observations[i].tickCumulative = last.tickCumulative + ticks[i] * timestampDelta
  //         observations[i].liquidityCumulative = last.liquidityCumulative + liquidities[i] * timestampDelta
  //       }
  //
  //       const oldestIndex = 0
  //       const newestIndex = observations.length - 1
  //
  //       const now = observations[newestIndex].blockTimestamp + 1
  //
  //       const observationsFixture = async () => {
  //         const oracle = await oracleFixture()
  //         await setOracle(oracle, observations, newestIndex, now, tick, liquidity)
  //         return oracle
  //       }
  //
  //       let oracle: OracleTest
  //       beforeEach('set the oracle', async () => {
  //         oracle = await loadFixture(observationsFixture)
  //       })
  //
  //       it('works for +1', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 1, now)
  //         )
  //         expect(tickCumulative).to.be.eq(ticks[1] * 1)
  //         expect(liquidityCumulative).to.be.eq(liquidities[1] * 1)
  //       })
  //       it('works for +2', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 2, now)
  //         )
  //         expect(tickCumulative).to.be.eq(ticks[1] * 2)
  //         expect(liquidityCumulative).to.be.eq(liquidities[1] * 2)
  //       })
  //
  //       it('works for +13', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 13, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[1].tickCumulative)
  //         expect(liquidityCumulative).to.be.eq(observations[1].liquidityCumulative)
  //       })
  //       it('works for +14', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 14, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[1].tickCumulative + ticks[2])
  //         expect(liquidityCumulative).to.be.eq(observations[1].liquidityCumulative + liquidities[2])
  //       })
  //
  //       it('works for boundary-1', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(getSecondsAgo(2 ** 32 - 1, now))
  //         expect(tickCumulative).to.be.eq(observations[230].tickCumulative + ticks[231] * 8)
  //         expect(liquidityCumulative).to.be.eq(observations[230].liquidityCumulative + liquidities[231] * 8)
  //       })
  //       it('works for boundary+1', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(getSecondsAgo(0, now))
  //         expect(tickCumulative).to.be.eq(observations[230].tickCumulative + ticks[231] * 9)
  //         expect(liquidityCumulative).to.be.eq(observations[230].liquidityCumulative + liquidities[231] * 9)
  //       })
  //
  //       it('works for +6655', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 6655, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[511].tickCumulative + ticks[512] * 12)
  //         expect(liquidityCumulative).to.be.eq(observations[511].liquidityCumulative + liquidities[512] * 12)
  //       })
  //       it('works for +6656', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 6656, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[512].tickCumulative)
  //         expect(liquidityCumulative).to.be.eq(observations[512].liquidityCumulative)
  //       })
  //       it('works for +6657', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 6657, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[512].tickCumulative + ticks[513])
  //         expect(liquidityCumulative).to.be.eq(observations[512].liquidityCumulative + liquidities[513])
  //       })
  //
  //       it('works for -2', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(2)
  //         expect(tickCumulative).to.be.eq(observations[newestIndex - 1].tickCumulative + ticks[1023] * 12)
  //         expect(liquidityCumulative).to.be.eq(
  //           observations[newestIndex - 1].liquidityCumulative + liquidities[1023] * 12
  //         )
  //       })
  //       it('works for -1', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(1)
  //         expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative)
  //         expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative)
  //       })
  //       it('works for 0', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(0)
  //         expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative + tick)
  //         expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative + liquidity)
  //       })
  //     })
  //
  //     describe('non-monotonic observations, shifted', () => {
  //       const start = 4294964297
  //
  //       const observations = getDefaultObservations()
  //
  //       for (let i = 0; i < observations.length; i++) {
  //         observations[i].initialized = true
  //         if (i === 0) {
  //           observations[i].blockTimestamp = start
  //           continue
  //         }
  //
  //         const last = observations[i - 1]
  //
  //         observations[i].blockTimestamp = (last.blockTimestamp + timestampDelta) % 2 ** 32
  //         observations[i].tickCumulative = last.tickCumulative + ticks[i] * timestampDelta
  //         observations[i].liquidityCumulative = last.liquidityCumulative + liquidities[i] * timestampDelta
  //       }
  //
  //       for (let i = 0; i < 100; i++) {
  //         observations.push(observations.shift()!)
  //       }
  //
  //       const oldestIndex = 924
  //       const newestIndex = 923
  //
  //       const now = observations[newestIndex].blockTimestamp + 1
  //
  //       const observationsFixture = async () => {
  //         const oracle = await oracleFixture()
  //         await setOracle(oracle, observations, newestIndex, now, tick, liquidity)
  //         return oracle
  //       }
  //
  //       let oracle: OracleTest
  //       beforeEach('set the oracle', async () => {
  //         oracle = await loadFixture(observationsFixture)
  //       })
  //
  //       it('works for +1', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 1, now)
  //         )
  //         expect(tickCumulative).to.be.eq(ticks[1] * 1)
  //         expect(liquidityCumulative).to.be.eq(liquidities[1] * 1)
  //       })
  //       it('works for +2', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 2, now)
  //         )
  //         expect(tickCumulative).to.be.eq(ticks[1] * 2)
  //         expect(liquidityCumulative).to.be.eq(liquidities[1] * 2)
  //       })
  //
  //       it('works for +13', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 13, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[oldestIndex + 1].tickCumulative)
  //         expect(liquidityCumulative).to.be.eq(observations[oldestIndex + 1].liquidityCumulative)
  //       })
  //       it('works for +14', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 14, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[oldestIndex + 1].tickCumulative + ticks[2])
  //         expect(liquidityCumulative).to.be.eq(observations[oldestIndex + 1].liquidityCumulative + liquidities[2])
  //       })
  //
  //       it('works for boundary-1', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(getSecondsAgo(2 ** 32 - 1, now))
  //         const index = (oldestIndex + 230) % CARDINALITY
  //         expect(tickCumulative).to.be.eq(observations[index].tickCumulative + ticks[231] * 8)
  //         expect(liquidityCumulative).to.be.eq(observations[index].liquidityCumulative + liquidities[231] * 8)
  //       })
  //       it('works for boundary+1', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(getSecondsAgo(0, now))
  //         const index = (oldestIndex + 230) % CARDINALITY
  //         expect(tickCumulative).to.be.eq(observations[index].tickCumulative + ticks[231] * 9)
  //         expect(liquidityCumulative).to.be.eq(observations[index].liquidityCumulative + liquidities[231] * 9)
  //       })
  //
  //       it('works for +6655', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 6655, now)
  //         )
  //         expect(tickCumulative).to.be.eq(
  //           observations[(oldestIndex + 511) % CARDINALITY].tickCumulative + ticks[512] * 12
  //         )
  //         expect(liquidityCumulative).to.be.eq(
  //           observations[(oldestIndex + 511) % CARDINALITY].liquidityCumulative + liquidities[512] * 12
  //         )
  //       })
  //       it('works for +6656', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 6656, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[(oldestIndex + 512) % CARDINALITY].tickCumulative)
  //         expect(liquidityCumulative).to.be.eq(observations[(oldestIndex + 512) % CARDINALITY].liquidityCumulative)
  //       })
  //       it('works for +6657', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(
  //           getSecondsAgo(observations[oldestIndex].blockTimestamp + 6657, now)
  //         )
  //         expect(tickCumulative).to.be.eq(observations[(oldestIndex + 512) % CARDINALITY].tickCumulative + ticks[513])
  //         expect(liquidityCumulative).to.be.eq(
  //           observations[(oldestIndex + 512) % CARDINALITY].liquidityCumulative + liquidities[513]
  //         )
  //       })
  //
  //       it('works for -2', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(2)
  //         expect(tickCumulative).to.be.eq(observations[newestIndex - 1].tickCumulative + ticks[1023] * 12)
  //         expect(liquidityCumulative).to.be.eq(
  //           observations[newestIndex - 1].liquidityCumulative + liquidities[1023] * 12
  //         )
  //       })
  //       it('works for -1', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(1)
  //         expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative)
  //         expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative)
  //       })
  //       it('works for 0', async () => {
  //         const { tickCumulative, liquidityCumulative } = await oracle.scry(0)
  //         expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative + tick)
  //         expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative + liquidity)
  //       })
  //     })
  //   })
  // })
})
