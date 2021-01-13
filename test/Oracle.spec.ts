import { BigNumber, constants } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { MockTimeUniswapV3Pair } from '../typechain/MockTimeUniswapV3Pair'
import { expect } from './shared/expect'
import { pairFixture } from './shared/fixtures'
import snapshotGasCost from './shared/snapshotGasCost'
import { FeeAmount, TICK_SPACINGS } from './shared/utilities'

const CARDINALITY = 1024

const UNINITIALIZED_OBSERVATION = {
  blockTimestamp: 0,
  tickCumulative: 0,
  liquidityCumulative: 0,
  initialized: false,
}

function getSecondsAgo(then: number, now: number) {
  const result = now >= then ? now - then : now + 2 ** 32 - then
  return result % 2 ** 32
}

async function setOracle(oracle: MockTimeUniswapV3Pair, observations: any, index: number = 0, time: number = 0) {
  await Promise.all([
    oracle.setObservations(observations.slice(0, 341) as any, 0),
    oracle.setObservations(observations.slice(341, 682) as any, 341),
    oracle.setObservations(observations.slice(682, 1024) as any, 682),
    oracle.setOracleData(index, time),
  ])
}

describe('Oracle', () => {
  const [wallet, other] = waffle.provider.getWallets()

  let loadFixture: ReturnType<typeof waffle.createFixtureLoader>
  before('create fixture loader', async () => {
    loadFixture = waffle.createFixtureLoader([wallet, other])
  })

  let oracle: MockTimeUniswapV3Pair

  describe('#getObservations', () => {
    before('deploy pair', async () => {
      const { createPair } = await loadFixture(pairFixture)
      oracle = await createPair(FeeAmount.MEDIUM, TICK_SPACINGS[FeeAmount.MEDIUM], 0)
    })

    it('length', async () => {
      const observations = await oracle.getObservations([0, 1, 2])
      expect(observations.length).to.be.eq(3)
    })

    it('contents', async () => {
      const observations = new Array(CARDINALITY).fill(UNINITIALIZED_OBSERVATION)
      observations[0] = {
        blockTimestamp: 0,
        tickCumulative: 0,
        liquidityCumulative: 0,
        initialized: true,
      }
      await setOracle(oracle, observations)
      const obs = await oracle.getObservations([0, 1])
      expect(obs[0].initialized).to.be.true
    })

    describe('#gas', async () => {
      it('1', async () => {
        await snapshotGasCost(await oracle.estimateGas.getObservations([0]))
      })
      it('2', async () => {
        await snapshotGasCost(await oracle.estimateGas.getObservations([0, 1]))
      })
      it('10', async () => {
        await snapshotGasCost(await oracle.estimateGas.getObservations(new Array(10).fill(0).map((_, i) => i)))
      })
      it('max', async () => {
        await snapshotGasCost(await oracle.estimateGas.getObservations(new Array(CARDINALITY).fill(0).map((_, i) => i)))
      }).timeout(60000)
    })
  })

  describe('#scry', () => {
    before('deploy pair', async () => {
      const { createPair } = await loadFixture(pairFixture)
      oracle = await createPair(FeeAmount.MEDIUM, TICK_SPACINGS[FeeAmount.MEDIUM], 0)
    })

    describe('failures', () => {
      it('fails while uninitialized', async () => {
        await expect(oracle.scry(0)).to.be.revertedWith('UI')
      })

      it('fails for single observation without any intervening time', async () => {
        const observations = new Array(CARDINALITY).fill(UNINITIALIZED_OBSERVATION)
        observations[0] = {
          blockTimestamp: 0,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
        await setOracle(oracle, observations)
        await expect(oracle.scry(0)).to.be.revertedWith('OLD')
      })
    })

    describe('successes', () => {
      it('timestamp equal to the most recent observation', async () => {
        const observations = new Array(CARDINALITY).fill(UNINITIALIZED_OBSERVATION)
        observations[0] = {
          blockTimestamp: 0,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
        observations[1] = {
          blockTimestamp: 1,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
        await setOracle(oracle, observations, 1, 1)

        const index = await oracle.scry(0)

        expect(index).to.be.eq(1)
      })

      it('timestamp greater than the most recent observation', async () => {
        const observations = new Array(CARDINALITY).fill(UNINITIALIZED_OBSERVATION)
        observations[0] = {
          blockTimestamp: 0,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
        await setOracle(oracle, observations, 0, 1)

        const index = await oracle.scry(0)

        expect(index).to.be.eq(CARDINALITY)
      })

      it('worst-case binary search', async () => {
        const observations = new Array(CARDINALITY).fill(UNINITIALIZED_OBSERVATION)
        observations[0] = {
          blockTimestamp: 0,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
        observations[1] = {
          blockTimestamp: 2,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
        await setOracle(oracle, observations, 1, 2)

        const index = await oracle.scry(1)

        expect(index).to.be.eq(1)
      })
    })

    describe('monotonic observations, unshifted', () => {
      const timestampDelta = 13
      const observations = new Array(CARDINALITY).fill(0).map((_, i) => {
        return {
          blockTimestamp: i * timestampDelta,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
      })

      const oldest = observations[0].blockTimestamp
      const now = observations[observations.length - 1].blockTimestamp + 1

      before(async () => {
        await setOracle(oracle, observations, observations.length - 1, now)
      })

      it('works for 1', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 1, now))

        expect(index).to.be.eq(1)
      })

      it('works for 2', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 2, now))

        expect(index).to.be.eq(1)
      })

      it('works for 13', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 13, now))

        expect(index).to.be.eq(1)
      })

      it('works for 14', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 14, now))

        expect(index).to.be.eq(2)
      })

      it('works for 6655', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 6655, now))

        expect(index).to.be.eq(512)
      })

      it('works for 6656', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 6656, now))

        expect(index).to.be.eq(512)
      })

      it('works for 6657', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 6657, now))

        expect(index).to.be.eq(513)
      })

      it('works for 13298', async () => {
        expect(getSecondsAgo(oldest + 13298, now)).to.be.eq(2)
        const index = await oracle.scry(2)

        expect(index).to.be.eq(1023)
      })

      it('works for 13299', async () => {
        expect(getSecondsAgo(oldest + 13299, now)).to.be.eq(1)
        const index = await oracle.scry(1)

        expect(index).to.be.eq(1023)
      })

      it('works for 13300', async () => {
        const index = await oracle.scry(0)

        expect(index).to.be.eq(CARDINALITY)
      })
    })

    describe('monotonic observations, shifted', () => {
      const timestampDelta = 13

      const observations = new Array(CARDINALITY).fill(0).map((_, i) => {
        return {
          blockTimestamp: i * timestampDelta,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
      })

      const oldest = observations[0].blockTimestamp
      const now = observations[observations.length - 1].blockTimestamp + 1

      for (let i = 0; i < 100; i++) {
        const shifted = observations.shift()
        observations.push(shifted!)
      }

      before(async () => {
        await setOracle(oracle, observations, 923, now)
      })

      it('works for 1', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 1, now))

        expect(index).to.be.eq(CARDINALITY + (1 - 100))
      })

      it('works for 13', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 13, now))

        expect(index).to.be.eq(CARDINALITY + (1 - 100))
      })

      it('works for 14', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 14, now))

        expect(index).to.be.eq(CARDINALITY + (2 - 100))
      })

      it('works for 6655', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 6655, now))

        expect(index).to.be.eq((CARDINALITY + (512 - 100)) % CARDINALITY)
      })

      it('works for 6656', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 6656, now))

        expect(index).to.be.eq((CARDINALITY + (512 - 100)) % CARDINALITY)
      })

      it('works for 6657', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 6657, now))

        expect(index).to.be.eq((CARDINALITY + (513 - 100)) % CARDINALITY)
      })

      it('works for 13298', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 13298, now))

        expect(index).to.be.eq((CARDINALITY + (1023 - 100)) % CARDINALITY)
      })

      it('works for 13299', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 13299, now))

        expect(index).to.be.eq((CARDINALITY + (1023 - 100)) % CARDINALITY)
      })

      it('works for 13300', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 13300, now))

        expect(index).to.be.eq(CARDINALITY)
      })
    })

    describe('non-monotonic observations, unshifted', () => {
      const oldest = 4294964296
      const timestampDelta = 13

      const observations = new Array(CARDINALITY)
        .fill(0)
        .map(() => {
          return {
            blockTimestamp: oldest,
            tickCumulative: 0,
            liquidityCumulative: 0,
            initialized: true,
          }
        })
        .map((observation, i, arr) => {
          if (i == 0) return observation
          observation.blockTimestamp = (arr[i - 1].blockTimestamp + timestampDelta) % 2 ** 32
          return observation
        })

      const now = observations[observations.length - 1].blockTimestamp + 2 ** 32 + 1

      before(async () => {
        await setOracle(oracle, observations, observations.length - 1, now)
      })

      it('works for +1', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 1, now))

        expect(index).to.be.eq(1)
      })

      it('works for +2', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 2, now))

        expect(index).to.be.eq(1)
      })

      it('works for +13', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 13, now))

        expect(index).to.be.eq(1)
      })

      it('works for +14', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 14, now))

        expect(index).to.be.eq(2)
      })

      it('works for boundary-2', async () => {
        const index = await oracle.scry(getSecondsAgo(2 ** 32 - 2, now))

        expect(index).to.be.eq(231)
      })

      it('works for boundary-1', async () => {
        const index = await oracle.scry(getSecondsAgo(2 ** 32 - 1, now))

        expect(index).to.be.eq(231)
      })

      it('works for boundary+1', async () => {
        const index = await oracle.scry(getSecondsAgo(0, now))

        expect(index).to.be.eq(231)
      })

      it('works for boundary+5', async () => {
        const index = await oracle.scry(getSecondsAgo(4, now))

        expect(index).to.be.eq(232)
      })

      it('works for newest-1', async () => {
        const index = await oracle.scry(getSecondsAgo(now - 2, now))

        expect(index).to.be.eq(1023)
      })

      it('works for newest', async () => {
        const index = await oracle.scry(getSecondsAgo(now - 1, now))

        expect(index).to.be.eq(1023)
      })

      it('works for newest+1', async () => {
        const index = await oracle.scry(0)

        expect(index).to.be.eq(CARDINALITY)
      })
    })

    describe('non-monotonic observations, shifted', () => {
      const oldest = 4294964296
      const timestampDelta = 13

      const observations = new Array(CARDINALITY)
        .fill(0)
        .map(() => {
          return {
            blockTimestamp: oldest,
            tickCumulative: 0,
            liquidityCumulative: 0,
            initialized: true,
          }
        })
        .map((observation, i, arr) => {
          if (i == 0) return observation
          observation.blockTimestamp = (arr[i - 1].blockTimestamp + timestampDelta) % 2 ** 32
          return observation
        })

      const now = observations[observations.length - 1].blockTimestamp + 2 ** 32 + 1

      for (let i = 0; i < 100; i++) {
        const shifted = observations.shift()
        observations.push(shifted!)
      }

      before(async () => {
        await setOracle(oracle, observations, 923, now)
      })

      it('works for +1', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 1, now))

        expect(index).to.be.eq(CARDINALITY + (1 - 100))
      })

      it('works for +13', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 13, now))

        expect(index).to.be.eq(CARDINALITY + (1 - 100))
      })

      it('works for +14', async () => {
        const index = await oracle.scry(getSecondsAgo(oldest + 14, now))

        expect(index).to.be.eq(CARDINALITY + (2 - 100))
      })

      it('works for boundary-2', async () => {
        const index = await oracle.scry(getSecondsAgo(2 ** 32 - 2, now))

        expect(index).to.be.eq((CARDINALITY + (231 - 100)) % CARDINALITY)
      })

      it('works for boundary-1', async () => {
        const index = await oracle.scry(getSecondsAgo(2 ** 32 - 1, now))

        expect(index).to.be.eq((CARDINALITY + (231 - 100)) % CARDINALITY)
      })

      it('works for boundary+1', async () => {
        const index = await oracle.scry(getSecondsAgo(0, now))

        expect(index).to.be.eq((CARDINALITY + (231 - 100)) % CARDINALITY)
      })

      it('works for boundary+5', async () => {
        const index = await oracle.scry(getSecondsAgo(4, now))

        expect(index).to.be.eq((CARDINALITY + (232 - 100)) % CARDINALITY)
      })

      it('works for newest-1', async () => {
        const index = await oracle.scry(getSecondsAgo(now - 2, now))

        expect(index).to.be.eq((CARDINALITY + (1023 - 100)) % CARDINALITY)
      })

      it('works for newest', async () => {
        const index = await oracle.scry(getSecondsAgo(now - 1, now))

        expect(index).to.be.eq((CARDINALITY + (1023 - 100)) % CARDINALITY)
      })

      it('works for newest+1', async () => {
        const index = await oracle.scry(0)

        expect(index).to.be.eq(CARDINALITY)
      })
    })

    describe('gas', () => {
      it('scry cost for timestamp equal to the most recent observation', async () => {
        const observations = new Array(CARDINALITY).fill(UNINITIALIZED_OBSERVATION)
        observations[0] = {
          blockTimestamp: 0,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
        observations[1] = {
          blockTimestamp: 1,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
        await setOracle(oracle, observations, 1, 1)
        await snapshotGasCost(await oracle.estimateGas.scry(0))
      })

      it('scry cost for timestamp greater than the most recent observation', async () => {
        const observations = new Array(CARDINALITY).fill(UNINITIALIZED_OBSERVATION)
        observations[0] = {
          blockTimestamp: 0,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
        await setOracle(oracle, observations, 0, 1)
        await snapshotGasCost(await oracle.estimateGas.scry(0))
      })

      it('scry cost for worst-case binary search', async () => {
        const observations = new Array(CARDINALITY).fill(UNINITIALIZED_OBSERVATION)
        observations[0] = {
          blockTimestamp: 0,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
        observations[1] = {
          blockTimestamp: 2,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
        await setOracle(oracle, observations, 1, 2)
        await snapshotGasCost(await oracle.estimateGas.scry(1))
      })
    })
  })
})
