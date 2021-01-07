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

describe('Oracle', () => {
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
      await expect(oracle.scry(1, 0, 0, 0)).to.be.revertedWith('BT')
    })

    it('fails while uninitialized', async () => {
      await expect(oracle.scry(0, 0, 0, 0)).to.be.revertedWith('UI')
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
      await expect(oracle.scry(0, 0, 0, 0)).to.be.revertedWith('OLD')
    })
  })

  describe('successes', () => {
    it('timestamp equal to the most recent observation', async () => {
      const tick = 123
      const liquidity = 456

      const observations = new Array(CARDINALITY).fill(UNINITIALIZED_OBSERVATION)
      observations[0] = {
        blockTimestamp: 0,
        tickCumulative: 0,
        liquidityCumulative: 0,
        initialized: true,
      }
      observations[1] = {
        blockTimestamp: 1,
        tickCumulative: tick,
        liquidityCumulative: liquidity,
        initialized: true,
      }
      await setOracle(observations)

      await oracle.setBlockTimestamp(1)

      const values = await oracle.scry(1, 1, 0, 0)

      expect(values.tick).to.be.eq(tick)
      expect(values.liquidity).to.be.eq(liquidity)
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

      const tick = 123
      const liquidity = 456

      const values = await oracle.scry(1, 0, tick, liquidity)

      expect(values.tick).to.be.eq(tick)
      expect(values.liquidity).to.be.eq(liquidity)
    })

    it('worst-case binary search', async () => {
      const tick = 123
      const liquidity = 456

      const observations = new Array(CARDINALITY).fill(UNINITIALIZED_OBSERVATION)
      observations[0] = {
        blockTimestamp: 0,
        tickCumulative: 0,
        liquidityCumulative: 0,
        initialized: true,
      }
      observations[1] = {
        blockTimestamp: 2,
        tickCumulative: tick * 2,
        liquidityCumulative: liquidity * 2,
        initialized: true,
      }
      await setOracle(observations)

      await oracle.setBlockTimestamp(2)

      const values = await oracle.scry(1, 1, 0, 0)

      expect(values.tick).to.be.eq(tick)
      expect(values.liquidity).to.be.eq(liquidity)
    })
  })

  describe('monotonic observations, unshifted', () => {
    const timestampDelta = 13
    const tickDelta = 2
    const liquidityDelta = 3

    const observations = new Array(CARDINALITY)
      .fill(0)
      .map((_, i) => {
        return {
          blockTimestamp: i * timestampDelta,
          tickCumulative: 0,
          liquidityCumulative: 0,
          initialized: true,
        }
      })
      .map((observation, i, arr) => {
        if (i == 0) return observation
        observation.tickCumulative = arr[i - 1].tickCumulative + i * tickDelta * timestampDelta
        observation.liquidityCumulative = arr[i - 1].liquidityCumulative + i * liquidityDelta * timestampDelta
        return observation
      })

    before(async () => {
      await setOracle(observations)
      await oracle.setBlockTimestamp(observations[observations.length - 1].blockTimestamp + 1)
    })

    it('works for 1', async () => {
      const values = await oracle.scry(1, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(1 * tickDelta)
      expect(values.liquidity).to.be.eq(1 * liquidityDelta)
    })

    it('works for 2', async () => {
      const values = await oracle.scry(2, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(1 * tickDelta)
      expect(values.liquidity).to.be.eq(1 * liquidityDelta)
    })

    it('works for 13', async () => {
      const values = await oracle.scry(13, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(1 * tickDelta)
      expect(values.liquidity).to.be.eq(1 * liquidityDelta)
    })

    it('works for 14', async () => {
      const values = await oracle.scry(14, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(2 * tickDelta)
      expect(values.liquidity).to.be.eq(2 * liquidityDelta)
    })

    it('works for 6655', async () => {
      const values = await oracle.scry(6655, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(512 * tickDelta)
      expect(values.liquidity).to.be.eq(512 * liquidityDelta)
    })

    it('works for 6656', async () => {
      const values = await oracle.scry(6656, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(512 * tickDelta)
      expect(values.liquidity).to.be.eq(512 * liquidityDelta)
    })

    it('works for 6657', async () => {
      const values = await oracle.scry(6657, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(513 * tickDelta)
      expect(values.liquidity).to.be.eq(513 * liquidityDelta)
    })

    it('works for 13298', async () => {
      const values = await oracle.scry(13298, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(1023 * tickDelta)
      expect(values.liquidity).to.be.eq(1023 * liquidityDelta)
    })

    it('works for 13299', async () => {
      const values = await oracle.scry(13299, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(1023 * tickDelta)
      expect(values.liquidity).to.be.eq(1023 * liquidityDelta)
    })

    it('works for 13300', async () => {
      const values = await oracle.scry(13300, observations.length - 1, 123, 456)

      expect(values.tick).to.be.eq(123)
      expect(values.liquidity).to.be.eq(456)
    })
  })

  describe('non-monotonic observations, unshifted', () => {
    const start = 4294964296
    const timestampDelta = 13
    const tickDelta = 2
    const liquidityDelta = 3

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
        observation.tickCumulative = arr[i - 1].tickCumulative + i * tickDelta * timestampDelta
        observation.liquidityCumulative = arr[i - 1].liquidityCumulative + i * liquidityDelta * timestampDelta
        return observation
      })

    before(async () => {
      await setOracle(observations)
      await oracle.setBlockTimestamp(observations[observations.length - 1].blockTimestamp + 2 ** 32 + 1)
    })

    it('works for +1', async () => {
      console.log(observations.length)

      const values = await oracle.scry(start + 1, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(1 * tickDelta)
      expect(values.liquidity).to.be.eq(1 * liquidityDelta)
    })

    it('works for +13', async () => {
      const values = await oracle.scry(start + 13, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(1 * tickDelta)
      expect(values.liquidity).to.be.eq(1 * liquidityDelta)
    })

    it('works for +14', async () => {
      const values = await oracle.scry(start + 14, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(2 * tickDelta)
      expect(values.liquidity).to.be.eq(2 * liquidityDelta)
    })

    it('works for boundary-2', async () => {
      const values = await oracle.scry(2 ** 32 - 2, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(231 * tickDelta)
      expect(values.liquidity).to.be.eq(231 * liquidityDelta)
    })

    it('works for boundary-1', async () => {
      const values = await oracle.scry(2 ** 32 - 1, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(231 * tickDelta)
      expect(values.liquidity).to.be.eq(231 * liquidityDelta)
    })

    it('works for boundary+1', async () => {
      const values = await oracle.scry(0, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(231 * tickDelta)
      expect(values.liquidity).to.be.eq(231 * liquidityDelta)
    })

    it('works for boundary+5', async () => {
      const values = await oracle.scry(4, observations.length - 1, 0, 0)

      expect(values.tick).to.be.eq(232 * tickDelta)
      expect(values.liquidity).to.be.eq(232 * liquidityDelta)
    })

    it('works for newest-1', async () => {
      const values = await oracle.scry(
        observations[observations.length - 1].blockTimestamp - 1,
        observations.length - 1,
        0,
        0
      )

      expect(values.tick).to.be.eq(1023 * tickDelta)
      expect(values.liquidity).to.be.eq(1023 * liquidityDelta)
    })

    it('works for newest', async () => {
      const values = await oracle.scry(
        observations[observations.length - 1].blockTimestamp,
        observations.length - 1,
        0,
        0
      )

      expect(values.tick).to.be.eq(1023 * tickDelta)
      expect(values.liquidity).to.be.eq(1023 * liquidityDelta)
    })

    it('works for newest +1', async () => {
      const values = await oracle.scry(
        observations[observations.length - 1].blockTimestamp + 1,
        observations.length - 1,
        123,
        456
      )

      expect(values.tick).to.be.eq(123)
      expect(values.liquidity).to.be.eq(456)
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
      await snapshotGasCost(await oracle.estimateGas.scry(1, 1, 0, 0))
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
      await snapshotGasCost(await oracle.estimateGas.scry(1, 0, 0, 0))
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
      await snapshotGasCost(await oracle.estimateGas.scry(1, 1, 0, 0))
    })
  })
})
