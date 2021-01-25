import { waffle } from 'hardhat'
import { Wallet } from 'ethers'
import { MockTimeUniswapV3Pair } from '../typechain/MockTimeUniswapV3Pair'
import { expect } from './shared/expect'

import { pairFixture, TEST_PAIR_START_TIME } from './shared/fixtures'
import snapshotGasCost from './shared/snapshotGasCost'

import {
  expandTo18Decimals,
  FeeAmount,
  getMinTick,
  encodePriceSqrt,
  TICK_SPACINGS,
  createPairFunctions,
  SwapFunction,
  MintFunction,
  getMaxTick,
  MaxUint128,
} from './shared/utilities'

const createFixtureLoader = waffle.createFixtureLoader

describe('UniswapV3Pair gas tests', () => {
  const [wallet, other] = waffle.provider.getWallets()

  let loadFixture: ReturnType<typeof createFixtureLoader>

  before('create fixture loader', async () => {
    loadFixture = createFixtureLoader([wallet, other])
  })

  for (const feeProtocol of [0, 6]) {
    describe(feeProtocol > 0 ? 'fee is on' : 'fee is off', () => {
      const startingPrice = encodePriceSqrt(100001, 100000)
      const startingTick = 0
      const startingTime = TEST_PAIR_START_TIME + 3
      const feeAmount = FeeAmount.MEDIUM
      const tickSpacing = TICK_SPACINGS[feeAmount]
      const minTick = getMinTick(tickSpacing)
      const maxTick = getMaxTick(tickSpacing)

      const gasTestFixture = async ([wallet]: Wallet[]) => {
        const fix = await pairFixture([wallet], waffle.provider)

        const pair = await fix.createPair(feeAmount, tickSpacing)

        await pair.setFeeProtocol(feeProtocol)

        const { swapExact0For1, swapToHigherPrice, mint } = await createPairFunctions({ ...fix, pair })

        await pair.initialize(encodePriceSqrt(1, 1))
        await pair.increaseObservationCardinality(4)
        await pair.advanceTime(1)
        await mint(wallet.address, minTick, maxTick, expandTo18Decimals(2))

        await swapExact0For1(expandTo18Decimals(1), wallet.address)
        await pair.advanceTime(1)
        await swapToHigherPrice(startingPrice, wallet.address)
        await pair.advanceTime(1)
        expect((await pair.slot0()).tick).to.eq(startingTick)
        expect((await pair.slot0()).sqrtPriceX96).to.eq(startingPrice)

        return { pair, swapExact0For1, mint, swapToHigherPrice }
      }

      let swapExact0For1: SwapFunction
      let swapToHigherPrice: SwapFunction
      let pair: MockTimeUniswapV3Pair
      let mint: MintFunction

      beforeEach('load the fixture', async () => {
        ;({ swapExact0For1, pair, mint, swapToHigherPrice } = await loadFixture(gasTestFixture))
      })

      describe('#swapExact0For1', () => {
        it('first swap in block with no tick movement', async () => {
          await snapshotGasCost(swapExact0For1(10, wallet.address))
          expect((await pair.slot0()).sqrtPriceX96).to.not.eq(startingPrice)
          expect((await pair.slot0()).tick).to.eq(startingTick)
        })

        it('first swap in block moves tick, no initialized crossings', async () => {
          await snapshotGasCost(swapExact0For1(expandTo18Decimals(1).div(10000), wallet.address))
          expect((await pair.slot0()).tick).to.eq(startingTick - 1)
        })

        it('second swap in block with no tick movement', async () => {
          await swapExact0For1(expandTo18Decimals(1).div(10000), wallet.address)
          expect((await pair.slot0()).tick).to.eq(startingTick - 1)
          await snapshotGasCost(swapExact0For1(1000, wallet.address))
          expect((await pair.slot0()).tick).to.eq(startingTick - 1)
        })

        it('second swap in block moves tick, no initialized crossings', async () => {
          await swapExact0For1(1000, wallet.address)
          expect((await pair.slot0()).tick).to.eq(startingTick)
          await snapshotGasCost(swapExact0For1(expandTo18Decimals(1).div(10000), wallet.address))
          expect((await pair.slot0()).tick).to.eq(startingTick - 1)
        })

        it('first swap in block, large swap, no initialized crossings', async () => {
          await snapshotGasCost(swapExact0For1(expandTo18Decimals(10), wallet.address))
          expect((await pair.slot0()).tick).to.eq(-35787)
        })

        it('first swap in block, large swap crossing several initialized ticks', async () => {
          await mint(wallet.address, startingTick - 3 * tickSpacing, startingTick - tickSpacing, expandTo18Decimals(1))
          await mint(
            wallet.address,
            startingTick - 4 * tickSpacing,
            startingTick - 2 * tickSpacing,
            expandTo18Decimals(1)
          )
          expect((await pair.slot0()).tick).to.eq(startingTick)
          await snapshotGasCost(swapExact0For1(expandTo18Decimals(1), wallet.address))
          expect((await pair.slot0()).tick).to.be.lte(startingTick - 4 * tickSpacing) // we crossed the last tick
        })

        it('first swap in block, large swap crossing a single initialized tick', async () => {
          await mint(wallet.address, minTick, startingTick - 2 * tickSpacing, expandTo18Decimals(1))
          await snapshotGasCost(swapExact0For1(expandTo18Decimals(1), wallet.address))
          expect((await pair.slot0()).tick).to.be.lte(startingTick - 2 * tickSpacing) // we crossed the last tick
        })

        it('second swap in block, large swap crossing several initialized ticks', async () => {
          await mint(wallet.address, startingTick - 3 * tickSpacing, startingTick - tickSpacing, expandTo18Decimals(1))
          await mint(
            wallet.address,
            startingTick - 4 * tickSpacing,
            startingTick - 2 * tickSpacing,
            expandTo18Decimals(1)
          )
          await swapExact0For1(expandTo18Decimals(1).div(10000), wallet.address)
          await snapshotGasCost(swapExact0For1(expandTo18Decimals(1), wallet.address))
          expect((await pair.slot0()).tick).to.be.lte(startingTick - 4 * tickSpacing)
        })

        it('second swap in block, large swap crossing a single initialized tick', async () => {
          await mint(wallet.address, minTick, startingTick - 2 * tickSpacing, expandTo18Decimals(1))
          await swapExact0For1(expandTo18Decimals(1).div(10000), wallet.address)
          expect((await pair.slot0()).tick).to.be.gt(startingTick - 2 * tickSpacing) // we didn't cross the initialized tick
          await snapshotGasCost(swapExact0For1(expandTo18Decimals(1), wallet.address))
          expect((await pair.slot0()).tick).to.be.lte(startingTick - 2 * tickSpacing) // we crossed the last tick
        })

        it('large swap crossing several initialized ticks after some time passes (seconds outside is set)', async () => {
          await mint(wallet.address, startingTick - 3 * tickSpacing, startingTick - tickSpacing, expandTo18Decimals(1))
          await mint(
            wallet.address,
            startingTick - 4 * tickSpacing,
            startingTick - 2 * tickSpacing,
            expandTo18Decimals(1)
          )
          await swapExact0For1(2, wallet.address)
          await pair.advanceTime(1)
          await snapshotGasCost(swapExact0For1(expandTo18Decimals(1), wallet.address))
          expect((await pair.slot0()).tick).to.be.lte(startingTick - 4 * tickSpacing)
        })

        it('large swap crossing several initialized ticks second time after some time passes', async () => {
          await mint(wallet.address, startingTick - 3 * tickSpacing, startingTick - tickSpacing, expandTo18Decimals(1))
          await mint(
            wallet.address,
            startingTick - 4 * tickSpacing,
            startingTick - 2 * tickSpacing,
            expandTo18Decimals(1)
          )
          await swapExact0For1(expandTo18Decimals(1), wallet.address)
          await swapToHigherPrice(startingPrice, wallet.address)
          await pair.advanceTime(1)
          await snapshotGasCost(swapExact0For1(expandTo18Decimals(1), wallet.address))
          expect((await pair.slot0()).tick).to.be.lt(tickSpacing * -4)
        })
      })

      describe('#mint', () => {
        for (const { description, tickLower, tickUpper } of [
          {
            description: 'around current price',
            tickLower: startingTick - tickSpacing,
            tickUpper: startingTick + tickSpacing,
          },
          {
            description: 'below current price',
            tickLower: startingTick - 2 * tickSpacing,
            tickUpper: startingTick - tickSpacing,
          },
          {
            description: 'above current price',
            tickLower: startingTick + tickSpacing,
            tickUpper: startingTick + 2 * tickSpacing,
          },
        ]) {
          describe(description, () => {
            it('new position mint first in range', async () => {
              await snapshotGasCost(mint(wallet.address, tickLower, tickUpper, expandTo18Decimals(1)))
            })
            it('add to position existing', async () => {
              await mint(wallet.address, tickLower, tickUpper, expandTo18Decimals(1))
              await snapshotGasCost(mint(wallet.address, tickLower, tickUpper, expandTo18Decimals(1)))
            })
            it('second position in same range', async () => {
              await mint(wallet.address, tickLower, tickUpper, expandTo18Decimals(1))
              await snapshotGasCost(mint(other.address, tickLower, tickUpper, expandTo18Decimals(1)))
            })
            it('add to position after some time passes', async () => {
              await mint(wallet.address, tickLower, tickUpper, expandTo18Decimals(1))
              await pair.advanceTime(1)
              await snapshotGasCost(mint(wallet.address, tickLower, tickUpper, expandTo18Decimals(1)))
            })
          })
        }
      })

      describe('#burn', () => {
        for (const { description, tickLower, tickUpper } of [
          {
            description: 'around current price',
            tickLower: startingTick - tickSpacing,
            tickUpper: startingTick + tickSpacing,
          },
          {
            description: 'below current price',
            tickLower: startingTick - 2 * tickSpacing,
            tickUpper: startingTick - tickSpacing,
          },
          {
            description: 'above current price',
            tickLower: startingTick + tickSpacing,
            tickUpper: startingTick + 2 * tickSpacing,
          },
        ]) {
          describe(description, () => {
            const liquidityAmount = expandTo18Decimals(1)
            beforeEach('mint a position', async () => {
              await mint(wallet.address, tickLower, tickUpper, liquidityAmount)
            })

            it('burn when only position using ticks', async () => {
              await snapshotGasCost(pair.burn(wallet.address, tickLower, tickUpper, expandTo18Decimals(1)))
            })
            it('partial position burn', async () => {
              await snapshotGasCost(pair.burn(wallet.address, tickLower, tickUpper, expandTo18Decimals(1).div(2)))
            })
            it('entire position burn but other positions are using the ticks', async () => {
              await mint(other.address, tickLower, tickUpper, expandTo18Decimals(1))
              await snapshotGasCost(pair.burn(wallet.address, tickLower, tickUpper, expandTo18Decimals(1)))
            })
            it('burn entire position after some time passes', async () => {
              await pair.advanceTime(1)
              await snapshotGasCost(pair.burn(wallet.address, tickLower, tickUpper, expandTo18Decimals(1)))
            })
          })
        }
      })

      describe('#poke', () => {
        const tickLower = startingTick - tickSpacing
        const tickUpper = startingTick + tickSpacing

        it('best case', async () => {
          await mint(wallet.address, tickLower, tickUpper, expandTo18Decimals(1))
          await swapExact0For1(expandTo18Decimals(1).div(100), wallet.address)
          await mint(wallet.address, tickLower, tickUpper, 0)
          await swapExact0For1(expandTo18Decimals(1).div(100), wallet.address)
          await snapshotGasCost(mint(wallet.address, tickLower, tickUpper, 0))
        })
      })

      describe('#collect', () => {
        const tickLower = startingTick - tickSpacing
        const tickUpper = startingTick + tickSpacing

        it('close to worst case', async () => {
          await mint(wallet.address, tickLower, tickUpper, expandTo18Decimals(1))
          await swapExact0For1(expandTo18Decimals(1).div(100), wallet.address)
          await mint(wallet.address, tickLower, tickUpper, 0) // poke to accumulate fees
          await snapshotGasCost(pair.collect(wallet.address, tickLower, tickUpper, MaxUint128, MaxUint128))
        })
      })
    })
  }
})
