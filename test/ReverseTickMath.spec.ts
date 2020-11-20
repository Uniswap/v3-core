import {BigNumber} from 'ethers'
import {ethers} from 'hardhat'
import {ReverseTickMathTest} from '../typechain/ReverseTickMathTest'

import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {encodePrice} from './shared/utilities'

describe('ReverseTickMath', () => {
  let reverseTickMath: ReverseTickMathTest
  before('deploy test contract', async () => {
    const reverseTickMathTest = await ethers.getContractFactory('ReverseTickMathTest')
    reverseTickMath = (await reverseTickMathTest.deploy()) as ReverseTickMathTest
  })

  describe('#getTickFromPrice', () => {
    const priceExactlyAtTickZero = {_x: BigNumber.from('340282366920938463463374607431768211456')}
    const priceCloseToTickZero = {_x: priceExactlyAtTickZero._x.add(1)}

    it('lowerBound = upperBound - 1', async () => {
      expect(await reverseTickMath.getTickFromPrice(priceCloseToTickZero, 0, 1)).to.eq(0)
    })

    it('lowerBound = upperBound - 4', async () => {
      expect(await reverseTickMath.getTickFromPrice(priceCloseToTickZero, -3, 1)).to.eq(0)
      expect(await reverseTickMath.getTickFromPrice(priceCloseToTickZero, -1, 3)).to.eq(0)
      expect(await reverseTickMath.getTickFromPrice(priceCloseToTickZero, 0, 4)).to.eq(0)
    })

    it('works for arbitrary prices', async () => {
      // got this tick from the spec
      const randomPriceAtTick365 = {_x: '12857036465196691992791697221653775109723'}
      expect(await reverseTickMath.getTickFromPrice(randomPriceAtTick365, 159, 693)).to.eq(365)
      expect(await reverseTickMath.getTickFromPrice(randomPriceAtTick365, 365, 404)).to.eq(365)
      expect(await reverseTickMath.getTickFromPrice(randomPriceAtTick365, 293, 366)).to.eq(365)
    })

    it('lowerBound and upper bound are both off', async () => {
      expect(await reverseTickMath.getTickFromPrice(priceCloseToTickZero, -3, 4)).to.eq(0)
      expect(await reverseTickMath.getTickFromPrice(priceCloseToTickZero, -4, 3)).to.eq(0)
    })

    it('lowerBound and upper bound off by 128', async () => {
      expect(await reverseTickMath.getTickFromPrice(priceCloseToTickZero, -128, 128)).to.eq(0)
    })
    it('price is at a tick below lower bound', async () => {
      expect(await reverseTickMath.getTickFromPrice(priceCloseToTickZero, 5, 250)).to.eq(5)
    })

    it('price is above upper bound', async () => {
      expect(await reverseTickMath.getTickFromPrice(priceCloseToTickZero, -100, -25)).to.eq(-26)
    })

    it('price is equal to upper bound', async () => {
      expect(await reverseTickMath.getTickFromPrice(priceExactlyAtTickZero, -100, 0)).to.eq(-1)
    })

    it('accuracy', async () => {
      expect(await reverseTickMath.getTickFromPrice({_x: '5192296858534827628530496329220095'}, -1, 0)).to.eq(-1)
    })
    it('throws if lowerBound == upperBound', async () => {
      await expect(reverseTickMath.getTickFromPrice(priceCloseToTickZero, 0, 0)).to.be.revertedWith(
        'ReverseTickMath::getTickFromPrice: lower bound must be less than upper bound'
      )
    })

    it('gas cost price exactly at 0', async () => {
      await snapshotGasCost(reverseTickMath.getGasCostOfGetTickFromPrice(priceExactlyAtTickZero, -128, 128))
    })
    it('gas cost 0 iterations', async () => {
      await snapshotGasCost(reverseTickMath.getGasCostOfGetTickFromPrice(priceCloseToTickZero, 0, 1))
    })
    it('gas cost diff of 8', async () => {
      await snapshotGasCost(reverseTickMath.getGasCostOfGetTickFromPrice(priceCloseToTickZero, -4, 4))
    })
    it('gas cost diff of 256', async () => {
      await snapshotGasCost(reverseTickMath.getGasCostOfGetTickFromPrice(priceCloseToTickZero, -128, 128))
    })
  })
})
