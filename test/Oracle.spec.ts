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
  offset: number,
  time = 0,
  tick = 0,
  liquidity = 0
) {
  await Promise.all([
    oracle.setObservations(observations.slice(0, 341), 0),
    oracle.setObservations(observations.slice(341, 682), 341),
    oracle.setObservations(observations.slice(682, 1024), 682),
    oracle.setOracleData(tick, liquidity, offset, time),
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

  describe('#scry', () => {
    describe('clean state tests', () => {
      let oracle: OracleTest
      beforeEach('deploy test oracle', async () => {
        oracle = await loadFixture(oracleFixture)
      })

      describe('failures', () => {
        it('fails while uninitialized', async () => {
          await expect(oracle.scry(0)).to.be.revertedWith('UI')
        })

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
          await snapshotGasCost(oracle.getGasCostOfObservationAt(0))
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
          await snapshotGasCost(oracle.getGasCostOfObservationAt(0))
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
          await snapshotGasCost(oracle.getGasCostOfObservationAt(1))
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
