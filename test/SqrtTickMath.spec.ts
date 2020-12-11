import {ethers} from 'hardhat'
import {SqrtTickMathTest} from '../typechain/SqrtTickMathTest'
import {expect} from './shared/expect'

const MIN_TICK = -689197
const MAX_TICK = 689197

describe('SqrtTickMath', () => {
  let sqrtTickMath: SqrtTickMathTest

  before('deploy TickMathTest', async () => {
    const sqrtTickMathTestFactory = await ethers.getContractFactory('SqrtTickMathTest')
    sqrtTickMath = (await sqrtTickMathTestFactory.deploy()) as SqrtTickMathTest
  })

  describe('#getSqrtRatioAtTick', () => {
    it('min tick', async () => {
      expect((await sqrtTickMath.getSqrtRatioAtTick(MIN_TICK))._x).to.eq('19997')
    })

    it('min tick +1', async () => {
      expect((await sqrtTickMath.getSqrtRatioAtTick(MIN_TICK + 1))._x).to.eq('19998')
    })

    it('max tick - 1', async () => {
      expect((await sqrtTickMath.getSqrtRatioAtTick(MAX_TICK - 1))._x).to.eq('17016587640562120376659286132668963')
    })
    it('max tick', async () => {
      expect((await sqrtTickMath.getSqrtRatioAtTick(MAX_TICK))._x).to.eq('17017438448674477402236614712524090')
    })
  })

  describe('#getTickAtSqrtRatio', () => {
    it('ratio of min tick', async () => {
      expect(await sqrtTickMath.getTickAtSqrtRatio({_x: 19997})).to.eq(MIN_TICK)
    })
    it('ratio of min tick + 1', async () => {
      expect(await sqrtTickMath.getTickAtSqrtRatio({_x: 19998})).to.eq(MIN_TICK + 1)
    })
    it('ratio of max tick - 1', async () => {
      expect(await sqrtTickMath.getTickAtSqrtRatio({_x: '17016587640562120376659286132668963'})).to.eq(MAX_TICK - 1)
    })
    it('ratio of max tick', async () => {
      expect(await sqrtTickMath.getTickAtSqrtRatio({_x: '17017438448674477402236614712524090'})).to.eq(MAX_TICK)
    })
  })
})
