import {BigNumber} from 'ethers'
import {ethers} from 'hardhat'
import {SqrtPriceMathTest} from '../typechain/SqrtPriceMathTest'

import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {encodePriceSqrt, expandTo18Decimals} from './shared/utilities'

describe('SqrtPriceMath', () => {
  let sqrtPriceMath: SqrtPriceMathTest
  before(async () => {
    const sqrtPriceMathTestFactory = await ethers.getContractFactory('SqrtPriceMathTest')
    sqrtPriceMath = (await sqrtPriceMathTestFactory.deploy()) as SqrtPriceMathTest
  })

  describe('#getNextPrice', () => {
    it('fails if price is zero', async () => {
      await expect(
        sqrtPriceMath.getNextPrice({_x: 0}, expandTo18Decimals(1), expandTo18Decimals(1).div(10), false)
      ).to.be.revertedWith('SqrtPriceMath::getNextPrice: sqrtP cannot be zero')
      await expect(
        sqrtPriceMath.getNextPrice({_x: 0}, expandTo18Decimals(1), expandTo18Decimals(1).div(10), true)
      ).to.be.revertedWith('SqrtPriceMath::getNextPrice: sqrtP cannot be zero')
    })

    it('fails if price is zero', async () => {
      await expect(
        sqrtPriceMath.getNextPrice({_x: encodePriceSqrt(1, 1)}, 0, expandTo18Decimals(1).div(10), false)
      ).to.be.revertedWith('SqrtPriceMath::getNextPrice: liquidity cannot be zero')
      await expect(
        sqrtPriceMath.getNextPrice({_x: encodePriceSqrt(1, 1)}, 0, expandTo18Decimals(1).div(10), true)
      ).to.be.revertedWith('SqrtPriceMath::getNextPrice: liquidity cannot be zero')
    })

    it('returns input price if amount in is zero', async () => {
      expect(
        (await sqrtPriceMath.getNextPrice({_x: encodePriceSqrt(1, 1)}, expandTo18Decimals(1).div(10), 0, false))._x
      ).to.eq(encodePriceSqrt(1, 1))
      expect(
        (await sqrtPriceMath.getNextPrice({_x: encodePriceSqrt(1, 1)}, expandTo18Decimals(1).div(10), 0, true))._x
      ).to.eq(encodePriceSqrt(1, 1))
    })

    it('sqrtQ is greater than sqrtP if one for zero', async () => {
      const sqrtQ = await sqrtPriceMath.getNextPrice(
        {_x: encodePriceSqrt(1, 1)},
        expandTo18Decimals(1),
        expandTo18Decimals(1).div(10),
        false
      )
      expect(sqrtQ._x).to.be.gt(encodePriceSqrt(1, 1))
    })
    it('sqrtQ is less than sqrtP if zero for one', async () => {
      const sqrtQ = await sqrtPriceMath.getNextPrice(
        {_x: encodePriceSqrt(1, 1)},
        expandTo18Decimals(1),
        expandTo18Decimals(1).div(10),
        true
      )
      expect(sqrtQ._x).to.be.lt(encodePriceSqrt(1, 1))
    })
    it('sqrtQ is equal to sqrtP if amount in is zero and swapping one for zero', async () => {
      const sqrtQ = await sqrtPriceMath.getNextPrice(
        {_x: encodePriceSqrt(1, 1)},
        expandTo18Decimals(1),
        BigNumber.from(0),
        false
      )
      expect(sqrtQ._x).to.eq(encodePriceSqrt(1, 1))
    })
    it('sqrtQ is equal to sqrtP if amount in is zero and swapping zero for one', async () => {
      const sqrtQ = await sqrtPriceMath.getNextPrice(
        {_x: encodePriceSqrt(1, 1)},
        expandTo18Decimals(1),
        BigNumber.from(0),
        true
      )
      expect(sqrtQ._x).to.eq(encodePriceSqrt(1, 1))
    })
    it('price of 1 to 1.21', async () => {
      const sqrtQ = await sqrtPriceMath.getNextPrice(
        {_x: encodePriceSqrt(1, 1)},
        expandTo18Decimals(1),
        expandTo18Decimals(1).div(10),
        false
      )
      expect(sqrtQ._x).to.eq(encodePriceSqrt(121, 100))
    })
    it('price of 1 to 1/1.21', async () => {
      const sqrtQ = await sqrtPriceMath.getNextPrice(
        {_x: encodePriceSqrt(1, 1)},
        expandTo18Decimals(1),
        expandTo18Decimals(1).div(10),
        true
      )
      // add 1 because we do not go all the way to the next price root
      expect(sqrtQ._x).to.eq(encodePriceSqrt(100, 121).add(1))
    })

    it('zeroForOne = true gas', async () => {
      await snapshotGasCost(
        sqrtPriceMath.getGasCostOfGetNextPrice(
          {_x: encodePriceSqrt(1, 1)},
          expandTo18Decimals(1),
          expandTo18Decimals(1).div(10),
          true
        )
      )
    })
    it('zeroForOne = false gas', async () => {
      await snapshotGasCost(
        sqrtPriceMath.getGasCostOfGetNextPrice(
          {_x: encodePriceSqrt(1, 1)},
          expandTo18Decimals(1),
          expandTo18Decimals(1).div(10),
          false
        )
      )
    })
  })

  describe('#getAmountDeltas', () => {
    it('reverts if prices have the wrong relation', async () => {
      await expect(
        sqrtPriceMath.getAmount0Delta({_x: encodePriceSqrt(1, 1).sub(1)}, {_x: encodePriceSqrt(1, 1)}, 0, true)
      ).to.be.reverted
      await expect(
        sqrtPriceMath.getAmount1Delta({_x: encodePriceSqrt(1, 1)}, {_x: encodePriceSqrt(1, 1).sub(1)}, 0, true)
      ).to.be.reverted
    })
    it('returns 0 if liquidity is 0', async () => {
      const amount0 = await sqrtPriceMath.getAmount0Delta(
        {_x: encodePriceSqrt(2, 1)},
        {_x: encodePriceSqrt(1, 1)},
        0,
        true
      )
      const amount1 = await sqrtPriceMath.getAmount1Delta(
        {_x: encodePriceSqrt(1, 1)},
        {_x: encodePriceSqrt(2, 1)},
        0,
        true
      )

      expect(amount0).to.eq(0)
      expect(amount1).to.eq(0)
    })
    it('returns 0 if prices are equal', async () => {
      const amount0 = await sqrtPriceMath.getAmount0Delta(
        {_x: encodePriceSqrt(1, 1)},
        {_x: encodePriceSqrt(1, 1)},
        0,
        true
      )
      const amount1 = await sqrtPriceMath.getAmount0Delta(
        {_x: encodePriceSqrt(1, 1)},
        {_x: encodePriceSqrt(1, 1)},
        0,
        true
      )

      expect(amount0).to.eq(0)
      expect(amount1).to.eq(0)
    })

    it('returns 0.1 amount1 for price of 1 to 1.21', async () => {
      const amount0 = await sqrtPriceMath.getAmount0Delta(
        {_x: encodePriceSqrt(121, 100)},
        {_x: encodePriceSqrt(1, 1)},
        expandTo18Decimals(1),
        true
      )
      const amount1 = await sqrtPriceMath.getAmount1Delta(
        {_x: encodePriceSqrt(1, 1)},
        {_x: encodePriceSqrt(121, 100)},
        expandTo18Decimals(1),
        true
      )

      expect(amount0).to.eq('90909090909090910')
      expect(amount1).to.eq('100000000000000000')

      const amount0RoundedDown = await sqrtPriceMath.getAmount0Delta(
        {_x: encodePriceSqrt(121, 100)},
        {_x: encodePriceSqrt(1, 1)},
        expandTo18Decimals(1),
        false
      )
      const amount1RoundedDown = await sqrtPriceMath.getAmount1Delta(
        {_x: encodePriceSqrt(1, 1)},
        {_x: encodePriceSqrt(121, 100)},
        expandTo18Decimals(1),
        false
      )

      expect(amount0RoundedDown).to.eq(amount0.sub(1))
      expect(amount1RoundedDown).to.eq(amount1.sub(1))
    })

    for (const roundUp of [true, false]) {
      it(`gas cost for amount0/${roundUp}`, async () => {
        await snapshotGasCost(
          sqrtPriceMath.getGasCostOfGetAmount0Delta(
            {_x: encodePriceSqrt(1, 1)},
            {_x: encodePriceSqrt(100, 121)},
            expandTo18Decimals(1),
            roundUp
          )
        )
      })

      it(`gas cost for amount1/${roundUp}`, async () => {
        await snapshotGasCost(
          sqrtPriceMath.getGasCostOfGetAmount1Delta(
            {_x: encodePriceSqrt(100, 121)},
            {_x: encodePriceSqrt(1, 1)},
            expandTo18Decimals(1),
            roundUp
          )
        )
      })
    }
  })
})
