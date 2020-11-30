import {ethers} from 'hardhat'
import {BigNumber, BigNumberish} from 'ethers'
import {TickMathTest} from '../typechain/TickMathTest'
import {TickMath1r01} from '../typechain/TickMath1r01'
import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {bnify2, MAX_TICK, MIN_TICK} from './shared/utilities'

const Q128 = BigNumber.from(2).pow(128)

describe('TickMath', () => {
  let tickMath1r01: TickMath1r01
  let tickMathTest: TickMathTest

  before('deploy TickMathTest', async () => {
    const tickMath1r01Factory = await ethers.getContractFactory('TickMath1r01')
    const tickMathTestFactory = await ethers.getContractFactory('TickMathTest')
    tickMath1r01 = (await tickMath1r01Factory.deploy()) as TickMath1r01
    tickMathTest = (await tickMathTestFactory.deploy(tickMath1r01.address)) as TickMathTest
  })

  describe('#getRatioAtTick', () => {
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
      function exactTickRatioQ128x128(tick: number): BigNumberish {
        const value = Q128.mul(BigNumber.from(101).pow(Math.abs(tick))).div(BigNumber.from(100).pow(Math.abs(tick)))
        return tick > 0 ? value : Q128.mul(Q128).div(value)
      }

      const ALLOWED_BIPS_DIFF = 1
      describe('small ticks', () => {
        for (let tick = 0; tick < 20; tick++) {
          it(`tick index: ${tick}`, async () => {
            await checkApproximatelyEquals(
              tickMathTest.getRatioAtTick(tick),
              exactTickRatioQ128x128(tick),
              ALLOWED_BIPS_DIFF
            )
          })
          if (tick !== 0) {
            it(`tick index: ${tick * -1}`, async () => {
              await checkApproximatelyEquals(
                tickMathTest.getRatioAtTick(tick * -1),
                exactTickRatioQ128x128(tick * -1),
                ALLOWED_BIPS_DIFF
              )
            })
          }
        }
      })

      describe('large ticks', () => {
        for (let tick of [50, 100, 250, 500, 1000, 2500, 3000, 4000, 5000, 6000, 7000, MAX_TICK]) {
          it(`tick index: ${tick}`, async () => {
            await checkApproximatelyEquals(
              tickMathTest.getRatioAtTick(tick),
              exactTickRatioQ128x128(tick),
              ALLOWED_BIPS_DIFF
            )
          })
          it(`tick index: ${tick * -1}`, async () => {
            await checkApproximatelyEquals(
              tickMathTest.getRatioAtTick(tick * -1),
              exactTickRatioQ128x128(tick * -1),
              ALLOWED_BIPS_DIFF
            )
          })
        }
      })
    })

    // these hand written tests make sure we are computing it roughly correctly
    it('returns exactly 1 for tick 0', async () => {
      await checkApproximatelyEquals(tickMathTest.getRatioAtTick(0), Q128, 0)
    })
    it('returns ~2/1 for tick 70', async () => {
      await checkApproximatelyEquals(tickMathTest.getRatioAtTick(70), BigNumber.from(2).mul(Q128), 34)
    })
    it('returns ~1/2 for tick -70', async () => {
      await checkApproximatelyEquals(tickMathTest.getRatioAtTick(-70), Q128.div(2), 34)
    })
    it('returns ~1/4 for tick -140', async () => {
      await checkApproximatelyEquals(tickMathTest.getRatioAtTick(-140), Q128.div(4), 70)
    })
    it('returns ~4/1 for tick 140', async () => {
      await checkApproximatelyEquals(tickMathTest.getRatioAtTick(140), Q128.mul(4), 70)
    })

    it('tick too large', async () => {
      await expect(tickMathTest.getRatioAtTick(MIN_TICK - 1)).to.be.revertedWith(
        'TickMath1r01::getRatioAtTick: invalid tick'
      )
    })
    it('tick too small', async () => {
      await expect(tickMathTest.getRatioAtTick(MAX_TICK + 1)).to.be.revertedWith(
        'TickMath1r01::getRatioAtTick: invalid tick'
      )
    })

    if (process.env.UPDATE_SNAPSHOT) {
      it('all tick values', async () => {
        const promises: Promise<{_x: BigNumber}>[] = []
        for (let tick = MIN_TICK; tick < MAX_TICK + 1; tick++) {
          promises.push(tickMathTest.getRatioAtTick(tick))
        }
        expect((await Promise.all(promises)).map(({_x: x}, i) => [MIN_TICK + i, x.toString()])).toMatchSnapshot()
      }).timeout(300000)
    }

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
    const ratioExactlyAtTickZero = {_x: BigNumber.from('340282366920938463463374607431768211456')}
    const ratioCloseToTickZero = {_x: ratioExactlyAtTickZero._x.add(1)}

    it('ratio too large', async () => {
      await expect(
        tickMathTest.getTickAtRatio({
          _x: BigNumber.from('19872759182565593239568746253641083721737304106191725165927866224867417'),
        })
      ).to.be.revertedWith('TickMath1r01::getTickAtRatio: invalid ratio')
    })
    it('ratio too small', async () => {
      await expect(tickMathTest.getTickAtRatio({_x: BigNumber.from('5826673')})).to.be.revertedWith(
        'TickMath1r01::getTickAtRatio: invalid ratio'
      )
    })
    it('ratio at min tick boundary', async () => {
      expect(await tickMathTest.getTickAtRatio({_x: BigNumber.from('5826674')})).to.eq(MIN_TICK)
    })
    it('ratio at max tick boundary', async () => {
      expect(
        await tickMathTest.getTickAtRatio({
          _x: BigNumber.from('19872759182565593239568746253641083721737304106191725165927866224867416'),
        })
      ).to.eq(MAX_TICK)
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
      const randomPriceAtTick365 = {_x: '12857036465196691992791697221653775109723'}
      expect(await tickMathTest.getTickAtRatio(randomPriceAtTick365)).to.eq(365)
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
      expect(await tickMathTest.getTickAtRatio({_x: '5192296858534827628530496329220095'})).to.eq(-1115)
    })

    it('gas cost price exactly at 0', async () => {
      await snapshotGasCost(tickMathTest.getTickAtRatioGasUsed(ratioExactlyAtTickZero))
    })
    it('gas cost random price', async () => {
      await snapshotGasCost(tickMathTest.getTickAtRatioGasUsed({_x: '12857036465196691992791697221653775109723'}))
    })
    it('gas cost another random price', async () => {
      await snapshotGasCost(tickMathTest.getTickAtRatioGasUsed({_x: '5192296858534827628530496329220095'}))
    })
  })
})
