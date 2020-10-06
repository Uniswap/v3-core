import { MockProvider, deployContract } from 'ethereum-waffle'
import { Contract, BigNumber, BigNumberish } from 'ethers'
import { expect } from './shared/expect'
import { bnify2 } from './shared/utilities'

import TickMathTest from '../build/TickMathTest.json'

const overrides = {
  gasLimit: 9999999,
}

const Q112 = BigNumber.from(2).pow(112)

describe('TickMath', () => {
  const provider = new MockProvider({
    ganacheOptions: {
      hardfork: 'istanbul',
      mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
      gasLimit: 9999999,
    },
  })
  const [wallet] = provider.getWallets()

  let tickMath: Contract
  before('deploy TickMathTest', async () => {
    tickMath = await deployContract(wallet, TickMathTest, [], overrides)
  })

  // checks that an actual number is within allowedDiffBips of an expected number
  async function checkApproximatelyEquals(
    actualP: BigNumberish | Promise<BigNumberish>,
    expectedP: BigNumberish | Promise<BigNumberish>,
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
      it('max tick', () => {
        // https://www.wolframalpha.com/input/?i=%281.01%5E7802%29+*+%282%5E112%29
        expect(exactTickRatioQ112x112(7802).toString()).to.eq(
          '26959868313666068472686589847821896098186460312140959350827207227142'
        )
      })
      it('-500 tick', () => {
        expect(exactTickRatioQ112x112(-500).toString()).to.eq('35865147646827690843910198668127')
      })

      it('-7000 tick', () => {
        expect(exactTickRatioQ112x112(-7000).toString()).to.eq('2922')
      })

      it('min tick', () => {
        expect(exactTickRatioQ112x112(-7801).toString()).to.eq('1')
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

    // because reserves are represented as uint112,
    // the max tick is going to be the tick corresponding to a price of 2^112/1 or 1/2^112
    // so log base 1.01 of 2^112 == 7802
    describe('large ticks', () => {
      for (let tick of [50, 100, 250, 500, 1000, 2500, 3000, 4000, 5000, 6000, 7000, 7802]) {
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
  it('returns ~1/4 for tick 140', async () => {
    await checkApproximatelyEquals(tickMath.getPrice(-140), Q112.div(4), 70)
  })
  it('returns ~4/1 for tick 140', async () => {
    await checkApproximatelyEquals(tickMath.getPrice(140), Q112.mul(4), 70)
  })

  it('tick too large', async () => {
    await expect(tickMath.getPrice(7803)).to.be.revertedWith('')
  })
  it('tick too small', async () => {
    await expect(tickMath.getPrice(-7803)).to.be.revertedWith('')
  })

  it.skip('all tick values', async () => {
    const promises: Promise<[BigNumber]>[] = []
    for (let tick = -7802; tick < 7803; tick++) {
      promises.push(tickMath.getPrice(tick))
    }
    expect((await Promise.all(promises)).map(([x], i) => [i - 7802, x.toString()])).toMatchSnapshot()
  }).timeout(300000)

  describe('gas', () => {
    const ticks = [-7802, -1000, -500, -50, 0, 50, 500, 1000, 7802]

    for (let tick of ticks) {
      it(`tick ${tick}`, async () => {
        const gasUsed = await tickMath.getGasUsed(tick)
        expect(gasUsed.toNumber()).toMatchSnapshot()
      })
    }
  })
})
