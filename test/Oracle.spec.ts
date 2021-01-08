import { BigNumberish } from 'ethers'
import { ethers } from 'hardhat'
import { OracleTest } from '../typechain/OracleTest'
import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'

const CARDINALITY = 1024

const UNINITIALIZED_OBSERVATION = {
  blockTimestamp: 0,
  tickCumulative: 0,
  liquidityCumulative: 0,
  initialized: false,
}

describe.only('Oracle', () => {
  let oracle: OracleTest

  async function setOracle(observations: any) {
    await oracle.setOracle(observations.slice(0, 256) as any, 0)
    await oracle.setOracle(observations.slice(256, 512) as any, 256)
    await oracle.setOracle(observations.slice(512, 768) as any, 512)
    await oracle.setOracle(observations.slice(768, 1024) as any, 768)
  }

  before('deploy OracleTest', async () => {
    const oracleTestFactory = await ethers.getContractFactory('OracleTest')
    oracle = (await oracleTestFactory.deploy()) as OracleTest
  })

  describe('failures', () => {
    it('fails if looking into the future', async () => {
      await expect(oracle.scry(1, 0)).to.be.revertedWith('BT')
    })

    it('fails while uninitialized', async () => {
      await expect(oracle.scry(0, 0)).to.be.revertedWith('UI')
    })

    it('fails for single observation without any intervening time', async () => {
      const observations = new Array(CARDINALITY).fill(UNINITIALIZED_OBSERVATION)
      observations[0] = {
        blockTimestamp: 0,
        tickCumulative: 0,
        liquidityCumulative: 0,
        initialized: true,
      }
      await setOracle(observations)
      await expect(oracle.scry(0, 0)).to.be.revertedWith('OLD')
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
      await setOracle(observations)

      await oracle.setBlockTimestamp(1)

      const index = await oracle.scry(1, 1)

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
      await setOracle(observations)

      await oracle.setBlockTimestamp(1)

      const index = await oracle.scry(1, 0)

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
      await setOracle(observations)

      await oracle.setBlockTimestamp(2)

      const index = await oracle.scry(1, 1)

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

    before(async () => {
      await setOracle(observations)
      await oracle.setBlockTimestamp(observations[observations.length - 1].blockTimestamp + 1)
    })

    it('works for 1', async () => {
      const index = await oracle.scry(1, observations.length - 1)

      expect(index).to.be.eq(1)
    })

    it('works for 2', async () => {
      const index = await oracle.scry(2, observations.length - 1)

      expect(index).to.be.eq(1)
    })

    it('works for 13', async () => {
      const index = await oracle.scry(13, observations.length - 1)

      expect(index).to.be.eq(1)
    })

    it('works for 14', async () => {
      const index = await oracle.scry(14, observations.length - 1)

      expect(index).to.be.eq(2)
    })

    it('works for 6655', async () => {
      const index = await oracle.scry(6655, observations.length - 1)

      expect(index).to.be.eq(512)
    })

    it('works for 6656', async () => {
      const index = await oracle.scry(6656, observations.length - 1)

      expect(index).to.be.eq(512)
    })

    it('works for 6657', async () => {
      const index = await oracle.scry(6657, observations.length - 1)

      expect(index).to.be.eq(513)
    })

    it('works for 13298', async () => {
      const index = await oracle.scry(13298, observations.length - 1)

      expect(index).to.be.eq(1023)
    })

    it('works for 13299', async () => {
      const index = await oracle.scry(13299, observations.length - 1)

      expect(index).to.be.eq(1023)
    })

    it('works for 13300', async () => {
      const index = await oracle.scry(13300, observations.length - 1)

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

    for (let i = 0; i < 100; i++) {
      const shifted = observations.shift()
      observations.push(shifted!)
    }

    before(async () => {
      await setOracle(observations)
      await oracle.setBlockTimestamp(observations[923].blockTimestamp + 1)
    })

    it('works for 1', async () => {
      const index = await oracle.scry(1, 923)

      expect(index).to.be.eq(CARDINALITY + (1 - 100))
    })

    it('works for 13', async () => {
      const index = await oracle.scry(13, 923)

      expect(index).to.be.eq(CARDINALITY + (1 - 100))
    })

    it('works for 14', async () => {
      const index = await oracle.scry(14, 923)

      expect(index).to.be.eq(CARDINALITY + (2 - 100))
    })

    it('works for 6655', async () => {
      const index = await oracle.scry(6655, 923)

      expect(index).to.be.eq((CARDINALITY + (512 - 100)) % CARDINALITY)
    })

    it('works for 6656', async () => {
      const index = await oracle.scry(6656, 923)

      expect(index).to.be.eq((CARDINALITY + (512 - 100)) % CARDINALITY)
    })

    it('works for 6657', async () => {
      const index = await oracle.scry(6657, 923)

      expect(index).to.be.eq((CARDINALITY + (513 - 100)) % CARDINALITY)
    })

    it('works for 13298', async () => {
      const index = await oracle.scry(13298, 923)

      expect(index).to.be.eq((CARDINALITY + (1023 - 100)) % CARDINALITY)
    })

    it('works for 13299', async () => {
      const index = await oracle.scry(13299, 923)

      expect(index).to.be.eq((CARDINALITY + (1023 - 100)) % CARDINALITY)
    })

    it('works for 13300', async () => {
      const index = await oracle.scry(13300, 923)

      expect(index).to.be.eq(CARDINALITY)
    })
  })

  describe('non-monotonic observations, unshifted', () => {
    const start = 4294964296
    const timestampDelta = 13

    const observations = new Array(CARDINALITY)
      .fill(0)
      .map(() => {
        return {
          blockTimestamp: start,
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

    before(async () => {
      await setOracle(observations)
      await oracle.setBlockTimestamp(observations[observations.length - 1].blockTimestamp + 2 ** 32 + 1)
    })

    it('works for +1', async () => {
      const index = await oracle.scry(start + 1, observations.length - 1)

      expect(index).to.be.eq(1)
    })

    it('works for +2', async () => {
      const index = await oracle.scry(start + 2, observations.length - 1)

      expect(index).to.be.eq(1)
    })

    it('works for +13', async () => {
      const index = await oracle.scry(start + 13, observations.length - 1)

      expect(index).to.be.eq(1)
    })

    it('works for +14', async () => {
      const index = await oracle.scry(start + 14, observations.length - 1)

      expect(index).to.be.eq(2)
    })

    it('works for boundary-2', async () => {
      const index = await oracle.scry(2 ** 32 - 2, observations.length - 1)

      expect(index).to.be.eq(231)
    })

    it('works for boundary-1', async () => {
      const index = await oracle.scry(2 ** 32 - 1, observations.length - 1)

      expect(index).to.be.eq(231)
    })

    it('works for boundary+1', async () => {
      const index = await oracle.scry(0, observations.length - 1)

      expect(index).to.be.eq(231)
    })

    it('works for boundary+5', async () => {
      const index = await oracle.scry(4, observations.length - 1)

      expect(index).to.be.eq(232)
    })

    it('works for newest-1', async () => {
      const index = await oracle.scry(observations[observations.length - 1].blockTimestamp - 1, observations.length - 1)

      expect(index).to.be.eq(1023)
    })

    it('works for newest', async () => {
      const index = await oracle.scry(observations[observations.length - 1].blockTimestamp, observations.length - 1)

      expect(index).to.be.eq(1023)
    })

    it('works for newest+1', async () => {
      const index = await oracle.scry(observations[observations.length - 1].blockTimestamp + 1, observations.length - 1)

      expect(index).to.be.eq(CARDINALITY)
    })
  })

  describe('non-monotonic observations, shifted', () => {
    const start = 4294964296
    const timestampDelta = 13

    const observations = new Array(CARDINALITY)
      .fill(0)
      .map(() => {
        return {
          blockTimestamp: start,
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

    for (let i = 0; i < 100; i++) {
      const shifted = observations.shift()
      observations.push(shifted!)
    }

    before(async () => {
      await setOracle(observations)
      await oracle.setBlockTimestamp(observations[923].blockTimestamp + 2 ** 32 + 1)
    })

    it('works for +1', async () => {
      const index = await oracle.scry(start + 1, 923)

      expect(index).to.be.eq(CARDINALITY + (1 - 100))
    })

    it('works for +13', async () => {
      const index = await oracle.scry(start + 13, 923)

      expect(index).to.be.eq(CARDINALITY + (1 - 100))
    })

    it('works for +14', async () => {
      const index = await oracle.scry(start + 14, 923)

      expect(index).to.be.eq(CARDINALITY + (2 - 100))
    })

    it('works for boundary-2', async () => {
      const index = await oracle.scry(2 ** 32 - 2, 923)

      expect(index).to.be.eq((CARDINALITY + (231 - 100)) % CARDINALITY)
    })

    it('works for boundary-1', async () => {
      const index = await oracle.scry(2 ** 32 - 1, 923)

      expect(index).to.be.eq((CARDINALITY + (231 - 100)) % CARDINALITY)
    })

    it('works for boundary+1', async () => {
      const index = await oracle.scry(0, 923)

      expect(index).to.be.eq((CARDINALITY + (231 - 100)) % CARDINALITY)
    })

    it('works for boundary+5', async () => {
      const index = await oracle.scry(4, 923)

      expect(index).to.be.eq((CARDINALITY + (232 - 100)) % CARDINALITY)
    })

    it('works for newest-1', async () => {
      const index = await oracle.scry(observations[923].blockTimestamp - 1, 923)

      expect(index).to.be.eq((CARDINALITY + (1023 - 100)) % CARDINALITY)
    })

    it('works for newest', async () => {
      const index = await oracle.scry(observations[923].blockTimestamp, 923)

      expect(index).to.be.eq((CARDINALITY + (1023 - 100)) % CARDINALITY)
    })

    it('works for newest+1', async () => {
      const index = await oracle.scry(observations[923].blockTimestamp + 1, 923)

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
      await setOracle(observations)
      await oracle.setBlockTimestamp(1)
      await snapshotGasCost(await oracle.estimateGas.scry(1, 1))
    })

    it('scry cost for timestamp greater than the most recent observation', async () => {
      const observations = new Array(CARDINALITY).fill(UNINITIALIZED_OBSERVATION)
      observations[0] = {
        blockTimestamp: 0,
        tickCumulative: 0,
        liquidityCumulative: 0,
        initialized: true,
      }
      await setOracle(observations)
      await oracle.setBlockTimestamp(1)
      await snapshotGasCost(await oracle.estimateGas.scry(1, 0))
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
      await setOracle(observations)
      await oracle.setBlockTimestamp(2)
      await snapshotGasCost(await oracle.estimateGas.scry(1, 1))
    })
  })
})
