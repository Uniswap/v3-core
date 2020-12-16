import {ethers} from 'hardhat'
import {BigNumber, BigNumberish} from 'ethers'
import {TickMathTest} from '../typechain/TickMathTest'
import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {Decimal} from 'decimal.js'

const MIN_TICK = -887272
const MAX_TICK = 887272

const Q128 = BigNumber.from(2).pow(128)

Decimal.config({toExpNeg: -500, toExpPos: 500})

// handles if the result is an array (in the case of fixed point struct return values where it's an array of one uint224)
export function bnify2(a: BigNumberish | [BigNumberish] | {0: BigNumberish}): BigNumber {
  if (Array.isArray(a)) {
    return BigNumber.from(a[0])
  } else {
    return BigNumber.from(a)
  }
}

describe('TickMath', () => {
  let tickMathTest: TickMathTest

  before('deploy TickMathTest', async () => {
    const tickMathTestFactory = await ethers.getContractFactory('TickMathTest')
    tickMathTest = (await tickMathTestFactory.deploy()) as TickMathTest
  })

  describe('#getRatioAtTick', () => {
    // checks that an actual number is within allowedDiffBips of an expected number
    async function checkApproximatelyEquals(
      actualP: BigNumberish | Promise<BigNumberish> | Promise<{0: BigNumberish}>,
      expectedP: BigNumberish | Promise<BigNumberish> | Promise<{0: BigNumberish}>,
      allowedDiffPips: BigNumberish
    ) {
      const [actual, expected] = [bnify2(await actualP), bnify2(await expectedP)]
      const absDiff = actual.sub(expected).abs()
      expect(
        absDiff.lte(expected.mul(allowedDiffPips).div(1000000)),
        `${actual.toString()} differs from ${expected.toString()} by >${allowedDiffPips.toString()}pips. 
      abs diff: ${absDiff.toString()}
      diff pips: ${absDiff.mul(1000000).div(expected).toString()}`
      ).to.be.true
    }

    describe('matches js implementation', () => {
      function exactTickRatioQ128x128(tick: number): BigNumberish {
        return BigNumber.from(new Decimal(1.0001).sqrt().pow(tick).mul(new Decimal(2).pow(128)).round().toString())
      }

      const ALLOWED_PIPS_DIFF = 35
      describe('small ticks', () => {
        for (let tick = 0; tick < 20; tick++) {
          it(`tick index: ${tick}`, async () => {
            await checkApproximatelyEquals(
              tickMathTest.getRatioAtTick(tick),
              exactTickRatioQ128x128(tick),
              ALLOWED_PIPS_DIFF
            )
          })
          if (tick !== 0) {
            it(`tick index: ${tick * -1}`, async () => {
              await checkApproximatelyEquals(
                tickMathTest.getRatioAtTick(tick * -1),
                exactTickRatioQ128x128(tick * -1),
                ALLOWED_PIPS_DIFF
              )
            })
          }
        }
      })

      describe('larger ticks', () => {
        for (let tick of [50, 100, 250, 500, 1000, 2500, 3000, 4000, 5000, 50000, 150000, 250000, 500000]) {
          it(`tick index: ${tick}`, async () => {
            await checkApproximatelyEquals(
              tickMathTest.getRatioAtTick(tick),
              exactTickRatioQ128x128(tick),
              ALLOWED_PIPS_DIFF
            )
          })
          it(`tick index: ${tick * -1}`, async () => {
            await checkApproximatelyEquals(
              tickMathTest.getRatioAtTick(tick * -1),
              exactTickRatioQ128x128(tick * -1),
              ALLOWED_PIPS_DIFF
            )
          })
        }
      })
    })

    // these hand written tests make sure we are computing it roughly correctly
    it('returns exactly 1 for tick 0', async () => {
      await checkApproximatelyEquals(tickMathTest.getRatioAtTick(0), Q128, 0)
    })
    it('tick for ratio ~2/1', async () => {
      await checkApproximatelyEquals(tickMathTest.getRatioAtTick(13863), '680543067898288706873709721891349895205', 1)
    })
    it('tick for ratio ~1/2', async () => {
      await checkApproximatelyEquals(tickMathTest.getRatioAtTick(-13863), '170146600118806920450031902982008185765', 1)
    })
    it('tick for ratio ~4/1', async () => {
      await checkApproximatelyEquals(tickMathTest.getRatioAtTick(27726), '1361042805288882125766385852078264339843', 1)
    })
    it('tick for ratio ~1/4', async () => {
      await checkApproximatelyEquals(tickMathTest.getRatioAtTick(-27726), '85076008474795366368843220463980381214', 1)
    })

    it('tick too small', async () => {
      await expect(tickMathTest.getRatioAtTick(MIN_TICK - 1)).to.be.revertedWith(
        'TickMath::getRatioAtTick: invalid tick'
      )
    })
    it('tick too large', async () => {
      await expect(tickMathTest.getRatioAtTick(MAX_TICK + 1)).to.be.revertedWith(
        'TickMath::getRatioAtTick: invalid tick'
      )
    })

    it('ratio at min tick boundary', async () => {
      expect((await tickMathTest.getRatioAtTick(MIN_TICK)).toString()).to.eq('18447437462383981825')
    })
    it('ratio at max tick boundary', async () => {
      expect((await tickMathTest.getRatioAtTick(MAX_TICK)).toString()).to.eq(
        '6276865796315986613307619852238232712866172378830071145882'
      )
    })

    describe('gas', () => {
      const ticks = [MIN_TICK, -1000, -500, -50, 0, 50, 500, 1000, MAX_TICK]

      for (let tick of ticks) {
        it(`tick ${tick}`, async () => {
          await snapshotGasCost(tickMathTest.getRatioAtTickGasUsed(tick))
        })
      }
    })
  })

  describe('#getTickAtRatio', () => {
    const ratioExactlyAtTickZero = BigNumber.from('340282366920938463463374607431768211456')
    const ratioCloseToTickZero = ratioExactlyAtTickZero.add(1)

    it('ratio too large', async () => {
      await expect(
        tickMathTest.getTickAtRatio(BigNumber.from('6276865796315986613307619852238232712866172378830071145882'))
      ).to.be.revertedWith('TickMath::getTickAtRatio: invalid ratio')
    })
    it('ratio too small', async () => {
      await expect(tickMathTest.getTickAtRatio(BigNumber.from('18447437462383981825').sub(1))).to.be.revertedWith(
        'TickMath::getTickAtRatio: invalid ratio'
      )
    })

    it('ratio at min tick boundary', async () => {
      expect(await tickMathTest.getTickAtRatio(BigNumber.from('18447437462383981825'))).to.eq(MIN_TICK)
    })
    it('ratio at max tick - 1 boundary', async () => {
      expect(
        await tickMathTest.getTickAtRatio(
          BigNumber.from('6276865796315986613307619852238232712866172378830071145882').sub(1)
        )
      ).to.eq(MAX_TICK - 1)
    })

    it('lowerBound = upperBound - 1', async () => {
      expect(await tickMathTest.getTickAtRatio(ratioCloseToTickZero)).to.eq(0)
    })

    it('lowerBound = upperBound - 4', async () => {
      expect(await tickMathTest.getTickAtRatio(ratioCloseToTickZero)).to.eq(0)
      expect(await tickMathTest.getTickAtRatio(ratioCloseToTickZero)).to.eq(0)
      expect(await tickMathTest.getTickAtRatio(ratioCloseToTickZero)).to.eq(0)
    })

    it('works for arbitrary prices', async () => {
      // got this tick from the spec
      const randomPriceAtTick365 = '12857036465196691992791697221653775109723'
      expect(await tickMathTest.getTickAtRatio(randomPriceAtTick365)).to.eq(72641)
    })

    it('lowerBound and upper bound are both off', async () => {
      expect(await tickMathTest.getTickAtRatio(ratioCloseToTickZero)).to.eq(0)
    })

    it('lowerBound and upper bound off by 128', async () => {
      expect(await tickMathTest.getTickAtRatio(ratioCloseToTickZero)).to.eq(0)
    })
    it('price is at a tick below lower bound', async () => {
      expect(await tickMathTest.getTickAtRatio(ratioCloseToTickZero)).to.eq(0)
    })

    it('accuracy', async () => {
      expect(await tickMathTest.getTickAtRatio('5192296858534827628530496329220095')).to.eq(-221819)
    })

    it('gas cost price exactly at 0', async () => {
      await snapshotGasCost(tickMathTest.getTickAtRatioGasUsed(ratioExactlyAtTickZero))
    })
    it('gas cost random price', async () => {
      await snapshotGasCost(tickMathTest.getTickAtRatioGasUsed('12857036465196691992791697221653775109723'))
    })
    it('gas cost another random price', async () => {
      await snapshotGasCost(tickMathTest.getTickAtRatioGasUsed('5192296858534827628530496329220095'))
    })
  })
})
