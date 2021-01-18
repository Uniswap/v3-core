import { ethers, waffle } from 'hardhat'
import { OracleTest } from '../typechain/OracleTest'
import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'

const CARDINALITY = 1024

interface Observation {
  blockTimestamp: number
  tickCumulative: number
  liquidityCumulative: number
  initialized: boolean
}

function getDefaultObservations(): Observation[] {
  return new Array(CARDINALITY).fill(null).map(() => ({
    blockTimestamp: 0,
    tickCumulative: 0,
    liquidityCumulative: 0,
    initialized: false,
  }))
}

function getSecondsAgo(then: number, now: number) {
  const result = now >= then ? now - then : now + 2 ** 32 - then
  return result % 2 ** 32
}

async function setOracle(
  oracle: OracleTest,
  observations: Observation[],
  index: number,
  time = 0,
  tick = 0,
  liquidity = 0,
  cardinality = 1024,
  target = 1024
) {
  await Promise.all([
    oracle.setObservations(observations.slice(0, 341), 0, index),
    oracle.setObservations(observations.slice(341, 682), 341, index),
    oracle.setObservations(observations.slice(682, 1024), 682, index),
    oracle.setOracleData(time, tick, liquidity, cardinality, target),
  ])
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

  describe('#write', () => {
    let oracle: OracleTest
    beforeEach('deploy test oracle', async () => {
      oracle = await loadFixture(oracleFixture)
    })

    it('does nothing if time has not changed', async () => {
      await oracle.advanceTime(1)
      await oracle.write(3, 2)
      expect(await oracle.index()).to.eq(1)
      await oracle.write(3, 2)
      expect(await oracle.index()).to.eq(1)
    })

    it('writes an index if time has changed', async () => {
      await oracle.advanceTime(1)
      await oracle.write(3, 2)
      expect(await oracle.index()).to.eq(1)
      const { tickCumulative, liquidityCumulative, initialized, blockTimestamp } = await oracle.observations(1)
      expect(initialized).to.eq(true)
      expect(tickCumulative).to.eq(0)
      expect(liquidityCumulative).to.eq(0)
      expect(blockTimestamp).to.eq(1)
    })

    it('accumulates liquidity', async () => {
      await oracle.advanceTime(3)
      await oracle.write(3, 2)
      await oracle.advanceTime(4)
      await oracle.write(-7, 6)
      await oracle.advanceTime(5)
      await oracle.write(-2, 4)

      expect(await oracle.index()).to.eq(3)
      let { tickCumulative, liquidityCumulative, initialized, blockTimestamp } = await oracle.observations(1)
      expect(initialized).to.eq(true)
      expect(tickCumulative).to.eq(0)
      expect(liquidityCumulative).to.eq(0)
      expect(blockTimestamp).to.eq(3)
      ;({ tickCumulative, liquidityCumulative, initialized, blockTimestamp } = await oracle.observations(2))
      expect(initialized).to.eq(true)
      expect(tickCumulative).to.eq(12)
      expect(liquidityCumulative).to.eq(8)
      expect(blockTimestamp).to.eq(7)
      ;({ tickCumulative, liquidityCumulative, initialized, blockTimestamp } = await oracle.observations(3))
      expect(initialized).to.eq(true)
      expect(tickCumulative).to.eq(-23)
      expect(liquidityCumulative).to.eq(38)
      expect(blockTimestamp).to.eq(12)
      ;({ tickCumulative, liquidityCumulative, initialized, blockTimestamp } = await oracle.observations(4))
      expect(initialized).to.eq(false)
    })
  })

  describe('#scry', () => {
    describe('clean state tests', () => {
      let oracle: OracleTest
      beforeEach('deploy test oracle', async () => {
        oracle = await loadFixture(oracleFixture)
      })

      describe('advancing cardinality target', () => {
        // TODO add more test cases here
        it('simple advance successful', async () => {
          await setOracle(
            oracle,
            [
              {
                blockTimestamp: 0,
                tickCumulative: 0,
                liquidityCumulative: 0,
                initialized: true,
              },
            ],
            0,
            13,
            2,
            3,
            1,
            1
          )

          await oracle.write(5, 5)

          const observation = await oracle.observations(0)
          expect(observation.blockTimestamp).to.be.eq(13)
          expect(observation.tickCumulative).to.be.eq(26)
          expect(observation.liquidityCumulative).to.be.eq(39)
          expect(observation.initialized).to.be.true

          await setOracle(
            oracle,
            [
              {
                blockTimestamp: 13,
                tickCumulative: 26,
                liquidityCumulative: 39,
                initialized: true,
              },
            ],
            0,
            14,
            5,
            5,
            1,
            2
          )

          await oracle.write(5, 5)

          const observation0 = await oracle.observations(0)
          expect(observation0).to.deep.eq(observation)

          const observation1 = await oracle.observations(1)
          expect(observation1.blockTimestamp).to.be.eq(14)
          expect(observation1.tickCumulative).to.be.eq(31)
          expect(observation1.liquidityCumulative).to.be.eq(44)
          expect(observation1.initialized).to.be.true
        })
      })

      describe('failures', () => {
        // TODO this doesn't work anymore because we initialize in the constructor
        // it('fails while uninitialized', async () => {
        //   await expect(oracle.scry(0)).to.be.revertedWith('UI')
        // })

        it('fails for single observation without any intervening time', async () => {
          await setOracle(
            oracle,
            [
              {
                blockTimestamp: 0,
                tickCumulative: 0,
                liquidityCumulative: 0,
                initialized: true,
              },
            ],
            0
          )
          await expect(oracle.scry(0)).to.be.revertedWith('OLD')
        })
      })

      describe('successes', () => {
        const tick = 123
        const liquidity = 456

        it('timestamp equal to the most recent observation', async () => {
          await setOracle(
            oracle,
            [
              {
                blockTimestamp: 0,
                tickCumulative: 0,
                liquidityCumulative: 0,
                initialized: true,
              },
              {
                blockTimestamp: 1,
                tickCumulative: tick,
                liquidityCumulative: liquidity,
                initialized: true,
              },
            ],
            1,
            1
          )
          const { tickCumulative, liquidityCumulative } = await oracle.scry(0)

          expect(tickCumulative).to.be.eq(tick)
          expect(liquidityCumulative).to.be.eq(liquidity)
        })

        it('timestamp greater than the most recent observation', async () => {
          await setOracle(
            oracle,
            [
              {
                blockTimestamp: 0,
                tickCumulative: 0,
                liquidityCumulative: 0,
                initialized: true,
              },
            ],
            0,
            2,
            tick,
            liquidity
          )

          let { tickCumulative, liquidityCumulative } = await oracle.scry(1)
          expect(tickCumulative).to.be.eq(tick)
          expect(liquidityCumulative).to.be.eq(liquidity)
          ;({ tickCumulative, liquidityCumulative } = await oracle.scry(0))
          expect(tickCumulative).to.be.eq(tick * 2)
          expect(liquidityCumulative).to.be.eq(liquidity * 2)
        })

        it('worst-case binary search', async () => {
          await setOracle(
            oracle,
            [
              {
                blockTimestamp: 0,
                tickCumulative: 0,
                liquidityCumulative: 0,
                initialized: true,
              },
              {
                blockTimestamp: 2,
                tickCumulative: tick * 2,
                liquidityCumulative: liquidity * 2,
                initialized: true,
              },
            ],
            1,
            2,
            tick,
            liquidity
          )

          const { tickCumulative, liquidityCumulative } = await oracle.scry(1)

          expect(tickCumulative).to.be.eq(tick)
          expect(liquidityCumulative).to.be.eq(liquidity)
        })
      })

      describe('gas', () => {
        it('timestamp equal to the most recent observation', async () => {
          await setOracle(
            oracle,
            [
              {
                blockTimestamp: 0,
                tickCumulative: 0,
                liquidityCumulative: 0,
                initialized: true,
              },
              {
                blockTimestamp: 1,
                tickCumulative: 0,
                liquidityCumulative: 0,
                initialized: true,
              },
            ],
            1,
            1
          )
          await snapshotGasCost(oracle.getGasCostOfScry(0))
        })

        it('timestamp greater than the most recent observation', async () => {
          await setOracle(
            oracle,
            [
              {
                blockTimestamp: 0,
                tickCumulative: 0,
                liquidityCumulative: 0,
                initialized: true,
              },
            ],
            0,
            1
          )
          await snapshotGasCost(oracle.getGasCostOfScry(0))
        })

        it('worst-case binary search', async () => {
          await setOracle(
            oracle,
            [
              {
                blockTimestamp: 0,
                tickCumulative: 0,
                liquidityCumulative: 0,
                initialized: true,
              },
              {
                blockTimestamp: 2,
                tickCumulative: 0,
                liquidityCumulative: 0,
                initialized: true,
              },
            ],
            1,
            2
          )
          await snapshotGasCost(oracle.getGasCostOfScry(1))
        })
      })
    })

    describe('full cases', () => {
      const timestampDelta = 13
      const ticks = new Array(CARDINALITY).fill(0).map((_, i) => i * 3)
      const liquidities = new Array(CARDINALITY).fill(0).map((_, i) => i * 4)

      const tick = 123
      const liquidity = 456

      describe('monotonic observations, unshifted', () => {
        const observations = getDefaultObservations()

        for (let i = 0; i < observations.length; i++) {
          observations[i].initialized = true
          if (i === 0) continue

          const last = observations[i - 1]

          observations[i].blockTimestamp = (last.blockTimestamp + timestampDelta) % 2 ** 32
          observations[i].tickCumulative = last.tickCumulative + ticks[i] * timestampDelta
          observations[i].liquidityCumulative = last.liquidityCumulative + liquidities[i] * timestampDelta
        }

        const oldestIndex = 0
        const newestIndex = observations.length - 1

        const now = observations[newestIndex].blockTimestamp + 1

        const observationsFixture = async () => {
          const oracle = await oracleFixture()
          await setOracle(oracle, observations, newestIndex, now, tick, liquidity)
          return oracle
        }

        let oracle: OracleTest
        beforeEach('set the oracle', async () => {
          oracle = await loadFixture(observationsFixture)
        })

        it('works for +1', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 1, now)
          )
          expect(tickCumulative).to.be.eq(ticks[1] * 1)
          expect(liquidityCumulative).to.be.eq(liquidities[1] * 1)
        })
        it('works for +2', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 2, now)
          )
          expect(tickCumulative).to.be.eq(ticks[1] * 2)
          expect(liquidityCumulative).to.be.eq(liquidities[1] * 2)
        })

        it('works for +13', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 13, now)
          )
          expect(tickCumulative).to.be.eq(observations[1].tickCumulative)
          expect(liquidityCumulative).to.be.eq(observations[1].liquidityCumulative)
        })
        it('works for +14', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 14, now)
          )
          expect(tickCumulative).to.be.eq(observations[1].tickCumulative + ticks[2])
          expect(liquidityCumulative).to.be.eq(observations[1].liquidityCumulative + liquidities[2])
        })

        it('works for +6655', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 6655, now)
          )
          expect(tickCumulative).to.be.eq(observations[511].tickCumulative + ticks[512] * 12)
          expect(liquidityCumulative).to.be.eq(observations[511].liquidityCumulative + liquidities[512] * 12)
        })
        it('works for +6656', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 6656, now)
          )
          expect(tickCumulative).to.be.eq(observations[512].tickCumulative)
          expect(liquidityCumulative).to.be.eq(observations[512].liquidityCumulative)
        })
        it('works for +6657', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 6657, now)
          )
          expect(tickCumulative).to.be.eq(observations[512].tickCumulative + ticks[513])
          expect(liquidityCumulative).to.be.eq(observations[512].liquidityCumulative + liquidities[513])
        })

        it('works for -2', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(2)
          expect(tickCumulative).to.be.eq(observations[newestIndex - 1].tickCumulative + ticks[1023] * 12)
          expect(liquidityCumulative).to.be.eq(
            observations[newestIndex - 1].liquidityCumulative + liquidities[1023] * 12
          )
        })
        it('works for -1', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(1)
          expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative)
          expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative)
        })
        it('works for 0', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(0)
          expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative + tick)
          expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative + liquidity)
        })
      })

      describe('monotonic observations, shifted', () => {
        const observations = getDefaultObservations()

        for (let i = 0; i < observations.length; i++) {
          observations[i].initialized = true
          if (i === 0) continue

          const last = observations[i - 1]

          observations[i].blockTimestamp = (last.blockTimestamp + timestampDelta) % 2 ** 32
          observations[i].tickCumulative = last.tickCumulative + ticks[i] * timestampDelta
          observations[i].liquidityCumulative = last.liquidityCumulative + liquidities[i] * timestampDelta
        }

        for (let i = 0; i < 100; i++) {
          observations.push(observations.shift()!)
        }

        const oldestIndex = 924
        const newestIndex = 923

        const now = observations[newestIndex].blockTimestamp + 1

        const observationsFixture = async () => {
          const oracle = await oracleFixture()
          await setOracle(oracle, observations, newestIndex, now, tick, liquidity)
          return oracle
        }

        let oracle: OracleTest
        beforeEach('set the oracle', async () => {
          oracle = await loadFixture(observationsFixture)
        })

        it('works for +1', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 1, now)
          )
          expect(tickCumulative).to.be.eq(ticks[1] * 1)
          expect(liquidityCumulative).to.be.eq(liquidities[1] * 1)
        })
        it('works for +2', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 2, now)
          )
          expect(tickCumulative).to.be.eq(ticks[1] * 2)
          expect(liquidityCumulative).to.be.eq(liquidities[1] * 2)
        })

        it('works for +13', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 13, now)
          )
          expect(tickCumulative).to.be.eq(observations[oldestIndex + 1].tickCumulative)
          expect(liquidityCumulative).to.be.eq(observations[oldestIndex + 1].liquidityCumulative)
        })
        it('works for +14', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 14, now)
          )
          expect(tickCumulative).to.be.eq(observations[oldestIndex + 1].tickCumulative + ticks[2])
          expect(liquidityCumulative).to.be.eq(observations[oldestIndex + 1].liquidityCumulative + liquidities[2])
        })

        it('works for +6655', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 6655, now)
          )
          expect(tickCumulative).to.be.eq(
            observations[(oldestIndex + 511) % CARDINALITY].tickCumulative + ticks[512] * 12
          )
          expect(liquidityCumulative).to.be.eq(
            observations[(oldestIndex + 511) % CARDINALITY].liquidityCumulative + liquidities[512] * 12
          )
        })
        it('works for +6656', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 6656, now)
          )
          expect(tickCumulative).to.be.eq(observations[(oldestIndex + 512) % CARDINALITY].tickCumulative)
          expect(liquidityCumulative).to.be.eq(observations[(oldestIndex + 512) % CARDINALITY].liquidityCumulative)
        })
        it('works for +6657', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 6657, now)
          )
          expect(tickCumulative).to.be.eq(observations[(oldestIndex + 512) % CARDINALITY].tickCumulative + ticks[513])
          expect(liquidityCumulative).to.be.eq(
            observations[(oldestIndex + 512) % CARDINALITY].liquidityCumulative + liquidities[513]
          )
        })

        it('works for -2', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(2)
          expect(tickCumulative).to.be.eq(observations[newestIndex - 1].tickCumulative + ticks[1023] * 12)
          expect(liquidityCumulative).to.be.eq(
            observations[newestIndex - 1].liquidityCumulative + liquidities[1023] * 12
          )
        })
        it('works for -1', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(1)
          expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative)
          expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative)
        })
        it('works for 0', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(0)
          expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative + tick)
          expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative + liquidity)
        })
      })

      describe('non-monotonic observations, unshifted', () => {
        const start = 4294964297

        const observations = getDefaultObservations()

        for (let i = 0; i < observations.length; i++) {
          observations[i].initialized = true
          if (i === 0) {
            observations[i].blockTimestamp = start
            continue
          }

          const last = observations[i - 1]

          observations[i].blockTimestamp = (last.blockTimestamp + timestampDelta) % 2 ** 32
          observations[i].tickCumulative = last.tickCumulative + ticks[i] * timestampDelta
          observations[i].liquidityCumulative = last.liquidityCumulative + liquidities[i] * timestampDelta
        }

        const oldestIndex = 0
        const newestIndex = observations.length - 1

        const now = observations[newestIndex].blockTimestamp + 1

        const observationsFixture = async () => {
          const oracle = await oracleFixture()
          await setOracle(oracle, observations, newestIndex, now, tick, liquidity)
          return oracle
        }

        let oracle: OracleTest
        beforeEach('set the oracle', async () => {
          oracle = await loadFixture(observationsFixture)
        })

        it('works for +1', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 1, now)
          )
          expect(tickCumulative).to.be.eq(ticks[1] * 1)
          expect(liquidityCumulative).to.be.eq(liquidities[1] * 1)
        })
        it('works for +2', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 2, now)
          )
          expect(tickCumulative).to.be.eq(ticks[1] * 2)
          expect(liquidityCumulative).to.be.eq(liquidities[1] * 2)
        })

        it('works for +13', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 13, now)
          )
          expect(tickCumulative).to.be.eq(observations[1].tickCumulative)
          expect(liquidityCumulative).to.be.eq(observations[1].liquidityCumulative)
        })
        it('works for +14', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 14, now)
          )
          expect(tickCumulative).to.be.eq(observations[1].tickCumulative + ticks[2])
          expect(liquidityCumulative).to.be.eq(observations[1].liquidityCumulative + liquidities[2])
        })

        it('works for boundary-1', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(getSecondsAgo(2 ** 32 - 1, now))
          expect(tickCumulative).to.be.eq(observations[230].tickCumulative + ticks[231] * 8)
          expect(liquidityCumulative).to.be.eq(observations[230].liquidityCumulative + liquidities[231] * 8)
        })
        it('works for boundary+1', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(getSecondsAgo(0, now))
          expect(tickCumulative).to.be.eq(observations[230].tickCumulative + ticks[231] * 9)
          expect(liquidityCumulative).to.be.eq(observations[230].liquidityCumulative + liquidities[231] * 9)
        })

        it('works for +6655', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 6655, now)
          )
          expect(tickCumulative).to.be.eq(observations[511].tickCumulative + ticks[512] * 12)
          expect(liquidityCumulative).to.be.eq(observations[511].liquidityCumulative + liquidities[512] * 12)
        })
        it('works for +6656', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 6656, now)
          )
          expect(tickCumulative).to.be.eq(observations[512].tickCumulative)
          expect(liquidityCumulative).to.be.eq(observations[512].liquidityCumulative)
        })
        it('works for +6657', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 6657, now)
          )
          expect(tickCumulative).to.be.eq(observations[512].tickCumulative + ticks[513])
          expect(liquidityCumulative).to.be.eq(observations[512].liquidityCumulative + liquidities[513])
        })

        it('works for -2', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(2)
          expect(tickCumulative).to.be.eq(observations[newestIndex - 1].tickCumulative + ticks[1023] * 12)
          expect(liquidityCumulative).to.be.eq(
            observations[newestIndex - 1].liquidityCumulative + liquidities[1023] * 12
          )
        })
        it('works for -1', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(1)
          expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative)
          expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative)
        })
        it('works for 0', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(0)
          expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative + tick)
          expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative + liquidity)
        })
      })

      describe('non-monotonic observations, shifted', () => {
        const start = 4294964297

        const observations = getDefaultObservations()

        for (let i = 0; i < observations.length; i++) {
          observations[i].initialized = true
          if (i === 0) {
            observations[i].blockTimestamp = start
            continue
          }

          const last = observations[i - 1]

          observations[i].blockTimestamp = (last.blockTimestamp + timestampDelta) % 2 ** 32
          observations[i].tickCumulative = last.tickCumulative + ticks[i] * timestampDelta
          observations[i].liquidityCumulative = last.liquidityCumulative + liquidities[i] * timestampDelta
        }

        for (let i = 0; i < 100; i++) {
          observations.push(observations.shift()!)
        }

        const oldestIndex = 924
        const newestIndex = 923

        const now = observations[newestIndex].blockTimestamp + 1

        const observationsFixture = async () => {
          const oracle = await oracleFixture()
          await setOracle(oracle, observations, newestIndex, now, tick, liquidity)
          return oracle
        }

        let oracle: OracleTest
        beforeEach('set the oracle', async () => {
          oracle = await loadFixture(observationsFixture)
        })

        it('works for +1', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 1, now)
          )
          expect(tickCumulative).to.be.eq(ticks[1] * 1)
          expect(liquidityCumulative).to.be.eq(liquidities[1] * 1)
        })
        it('works for +2', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 2, now)
          )
          expect(tickCumulative).to.be.eq(ticks[1] * 2)
          expect(liquidityCumulative).to.be.eq(liquidities[1] * 2)
        })

        it('works for +13', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 13, now)
          )
          expect(tickCumulative).to.be.eq(observations[oldestIndex + 1].tickCumulative)
          expect(liquidityCumulative).to.be.eq(observations[oldestIndex + 1].liquidityCumulative)
        })
        it('works for +14', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 14, now)
          )
          expect(tickCumulative).to.be.eq(observations[oldestIndex + 1].tickCumulative + ticks[2])
          expect(liquidityCumulative).to.be.eq(observations[oldestIndex + 1].liquidityCumulative + liquidities[2])
        })

        it('works for boundary-1', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(getSecondsAgo(2 ** 32 - 1, now))
          const index = (oldestIndex + 230) % CARDINALITY
          expect(tickCumulative).to.be.eq(observations[index].tickCumulative + ticks[231] * 8)
          expect(liquidityCumulative).to.be.eq(observations[index].liquidityCumulative + liquidities[231] * 8)
        })
        it('works for boundary+1', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(getSecondsAgo(0, now))
          const index = (oldestIndex + 230) % CARDINALITY
          expect(tickCumulative).to.be.eq(observations[index].tickCumulative + ticks[231] * 9)
          expect(liquidityCumulative).to.be.eq(observations[index].liquidityCumulative + liquidities[231] * 9)
        })

        it('works for +6655', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 6655, now)
          )
          expect(tickCumulative).to.be.eq(
            observations[(oldestIndex + 511) % CARDINALITY].tickCumulative + ticks[512] * 12
          )
          expect(liquidityCumulative).to.be.eq(
            observations[(oldestIndex + 511) % CARDINALITY].liquidityCumulative + liquidities[512] * 12
          )
        })
        it('works for +6656', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 6656, now)
          )
          expect(tickCumulative).to.be.eq(observations[(oldestIndex + 512) % CARDINALITY].tickCumulative)
          expect(liquidityCumulative).to.be.eq(observations[(oldestIndex + 512) % CARDINALITY].liquidityCumulative)
        })
        it('works for +6657', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(
            getSecondsAgo(observations[oldestIndex].blockTimestamp + 6657, now)
          )
          expect(tickCumulative).to.be.eq(observations[(oldestIndex + 512) % CARDINALITY].tickCumulative + ticks[513])
          expect(liquidityCumulative).to.be.eq(
            observations[(oldestIndex + 512) % CARDINALITY].liquidityCumulative + liquidities[513]
          )
        })

        it('works for -2', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(2)
          expect(tickCumulative).to.be.eq(observations[newestIndex - 1].tickCumulative + ticks[1023] * 12)
          expect(liquidityCumulative).to.be.eq(
            observations[newestIndex - 1].liquidityCumulative + liquidities[1023] * 12
          )
        })
        it('works for -1', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(1)
          expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative)
          expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative)
        })
        it('works for 0', async () => {
          const { tickCumulative, liquidityCumulative } = await oracle.scry(0)
          expect(tickCumulative).to.be.eq(observations[newestIndex].tickCumulative + tick)
          expect(liquidityCumulative).to.be.eq(observations[newestIndex].liquidityCumulative + liquidity)
        })
      })
    })
  })
})
