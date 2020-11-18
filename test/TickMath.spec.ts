import {ethers} from 'hardhat'
import {Contract, BigNumber, BigNumberish} from 'ethers'
import {TickMathTest} from '../typechain/TickMathTest'
import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {bnify2, MAX_TICK, MIN_TICK} from './shared/utilities'

const Q112 = BigNumber.from(2).pow(112)

describe('TickMath', () => {
  let tickMath: TickMathTest
  before('deploy TickMathTest', async () => {
    const tickMathTestFactory = await ethers.getContractFactory('TickMathTest')
    tickMath = (await tickMathTestFactory.deploy()) as TickMathTest
  })

  // checks that an actual number is within allowedDiffBips of an expected number
  async function checkApproximatelyEquals(
    actualP: BigNumberish | Promise<BigNumberish> | Promise<{0: BigNumberish}>,
    expectedP: BigNumberish | Promise<BigNumberish> | Promise<{0: BigNumberish}>,
    allowedDiffBips: BigNumberish
  ) {
    const [actual, expected] = [bnify2(await actualP), bnify2(await expectedP)]
    const absDiff = actual.sub(expected).abs()
    expect(
      absDiff.lte(expected.mul(allowedDiffBips).div(10000)),
      `${actual.toString()} differs from ${expected.toString()} by >${allowedDiffBips.toString()}bips. 
      abs diff: ${absDiff.toString()}
      diff bips: ${absDiff.mul(10000).div(expected).toString()}`
    ).to.be.true
  }

  describe('matches js implementation', () => {
    function exactTickRatioQ112x112(tick: number): BigNumberish {
      const value = Q112.mul(BigNumber.from(101).pow(Math.abs(tick))).div(BigNumber.from(100).pow(Math.abs(tick)))
      return tick > 0 ? value : Q112.mul(Q112).div(value)
    }

    describe('js implementation', () => {
      it('min tick (math)', () => {
        // https://www.wolframalpha.com/input/?i=1.01**7351+*+2**112
        expect(exactTickRatioQ112x112(MIN_TICK).toString()).to.eq('88')
      })

      it('min tick (impl)', () => {
        expect(exactTickRatioQ112x112(MIN_TICK).toString()).to.eq('88')
      })

      it('max tick (math)', () => {
        // https://www.wolframalpha.com/input/?i=1.01**7351+*+2**112
        expect(exactTickRatioQ112x112(MAX_TICK).toString()).to.eq(
          '303234206515492778604670563942879899541683825327377805701311231077'
        )
      })

      it('max tick (impl)', () => {
        expect(exactTickRatioQ112x112(MAX_TICK).toString()).to.eq(
          '303234206515492778604670563942879899541683825327377805701311231077'
        )
      })

      it('-500 tick', () => {
        expect(exactTickRatioQ112x112(-500).toString()).to.eq('35865147646827690843910198668127')
      })

      it('-7000 tick', () => {
        expect(exactTickRatioQ112x112(-7000).toString()).to.eq('2922')
      })
    })

    const ALLOWED_BIPS_DIFF = 1
    describe('small ticks', () => {
      for (let tick = 0; tick < 20; tick++) {
        it(`tick index: ${tick}`, async () => {
          await checkApproximatelyEquals(tickMath.getPrice(tick), exactTickRatioQ112x112(tick), ALLOWED_BIPS_DIFF)
        })
        if (tick !== 0) {
          it(`tick index: ${tick * -1}`, async () => {
            await checkApproximatelyEquals(
              tickMath.getPrice(tick * -1),
              exactTickRatioQ112x112(tick * -1),
              ALLOWED_BIPS_DIFF
            )
          })
        }
      }
    })

    describe('large ticks', () => {
      for (let tick of [50, 100, 250, 500, 1000, 2500, 3000, 4000, 5000, 6000, 7000, MAX_TICK]) {
        it(`tick index: ${tick}`, async () => {
          await checkApproximatelyEquals(tickMath.getPrice(tick), exactTickRatioQ112x112(tick), ALLOWED_BIPS_DIFF)
        })
        it(`tick index: ${tick * -1}`, async () => {
          await checkApproximatelyEquals(
            tickMath.getPrice(tick * -1),
            exactTickRatioQ112x112(tick * -1),
            ALLOWED_BIPS_DIFF
          )
        })
      }
    })
  })

  // these hand written tests make sure we are computing it roughly correctly
  it('returns exactly 1 for tick 0', async () => {
    await checkApproximatelyEquals(tickMath.getPrice(0), Q112, 0)
  })
  it('returns ~2/1 for tick 70', async () => {
    await checkApproximatelyEquals(tickMath.getPrice(70), BigNumber.from(2).mul(Q112), 34)
  })
  it('returns ~1/2 for tick -70', async () => {
    await checkApproximatelyEquals(tickMath.getPrice(-70), Q112.div(2), 34)
  })
  it('returns ~1/4 for tick -140', async () => {
    await checkApproximatelyEquals(tickMath.getPrice(-140), Q112.div(4), 70)
  })
  it('returns ~4/1 for tick 140', async () => {
    await checkApproximatelyEquals(tickMath.getPrice(140), Q112.mul(4), 70)
  })

  it('tick too large', async () => {
    await expect(tickMath.getPrice(MIN_TICK - 1)).to.be.revertedWith('')
  })
  it('tick too small', async () => {
    await expect(tickMath.getPrice(MAX_TICK + 1)).to.be.revertedWith('')
  })

  if (process.env.UPDATE_SNAPSHOT) {
    it('all tick values', async () => {
      const promises: Promise<{_x: BigNumber}>[] = []
      for (let tick = MIN_TICK; tick < MAX_TICK + 1; tick++) {
        promises.push(tickMath.getPrice(tick))
      }
      expect((await Promise.all(promises)).map(({_x: x}, i) => [MIN_TICK + i, x.toString()])).toMatchSnapshot()
    }).timeout(300000)
  }

  describe('gas', () => {
    const ticks = [MIN_TICK, -1000, -500, -50, 0, 50, 500, 1000, MAX_TICK]

    for (let tick of ticks) {
      it(`tick ${tick}`, async () => {
        await snapshotGasCost(tickMath.getGasUsed(tick))
      })
    }
  })
})
