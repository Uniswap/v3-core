import {BigNumber} from 'ethers'
import {ethers} from 'hardhat'
import {SqrtPriceMathTest} from '../typechain/SqrtPriceMathTest'

import {expect} from './shared/expect'
import {encodePriceSqrt, expandTo18Decimals} from './shared/utilities'

describe.only('SqrtPriceMath', () => {
  let sqrtPriceMath: SqrtPriceMathTest
  before(async () => {
    const sqrtPriceMathTestFactory = await ethers.getContractFactory('SqrtPriceMathTest')
    sqrtPriceMath = (await sqrtPriceMathTestFactory.deploy()) as SqrtPriceMathTest
  })

  describe('#getPriceAfterSwap', () => {
    it('fails if price is zero', async () => {
      await expect(
        sqrtPriceMath.getPriceAfterSwap(0, expandTo18Decimals(1), expandTo18Decimals(1).div(10), false)
      ).to.be.revertedWith('SqrtPriceMath::getPriceAfterSwap: sqrtP cannot be zero')
      await expect(
        sqrtPriceMath.getPriceAfterSwap(0, expandTo18Decimals(1), expandTo18Decimals(1).div(10), true)
      ).to.be.revertedWith('SqrtPriceMath::getPriceAfterSwap: sqrtP cannot be zero')
    })

    it('fails if price is zero', async () => {
      await expect(
        sqrtPriceMath.getPriceAfterSwap(encodePriceSqrt(1, 1), 0, expandTo18Decimals(1).div(10), false)
      ).to.be.revertedWith('SqrtPriceMath::getPriceAfterSwap: liquidity cannot be zero')
      await expect(
        sqrtPriceMath.getPriceAfterSwap(encodePriceSqrt(1, 1), 0, expandTo18Decimals(1).div(10), true)
      ).to.be.revertedWith('SqrtPriceMath::getPriceAfterSwap: liquidity cannot be zero')
    })

    it('returns input price if amount in is zero', async () => {
      expect(
        await sqrtPriceMath.getPriceAfterSwap(encodePriceSqrt(1, 1), expandTo18Decimals(1).div(10), 0, false)
      ).to.eq(encodePriceSqrt(1, 1))
      expect(
        await sqrtPriceMath.getPriceAfterSwap(encodePriceSqrt(1, 1), expandTo18Decimals(1).div(10), 0, true)
      ).to.eq(encodePriceSqrt(1, 1))
    })

    it('sqrtQ is greater than sqrtP if one for zero', async () => {
      const sqrtQ = await sqrtPriceMath.getPriceAfterSwap(
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1),
        expandTo18Decimals(1).div(10),
        false
      )
      expect(sqrtQ).to.be.gt(encodePriceSqrt(1, 1))
    })
    it('sqrtQ is less than sqrtP if zero for one', async () => {
      const sqrtQ = await sqrtPriceMath.getPriceAfterSwap(
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1),
        expandTo18Decimals(1).div(10),
        true
      )
      expect(sqrtQ).to.be.lt(encodePriceSqrt(1, 1))
    })
    it('sqrtQ is equal to sqrtP if amount in is zero and swapping one for zero', async () => {
      const sqrtQ = await sqrtPriceMath.getPriceAfterSwap(
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1),
        BigNumber.from(0),
        false
      )
      expect(sqrtQ).to.eq(encodePriceSqrt(1, 1))
    })
    it('sqrtQ is equal to sqrtP if amount in is zero and swapping zero for one', async () => {
      const sqrtQ = await sqrtPriceMath.getPriceAfterSwap(
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1),
        BigNumber.from(0),
        true
      )
      expect(sqrtQ).to.eq(encodePriceSqrt(1, 1))
    })
    it('price of 1 to 1.21', async () => {
      const sqrtQ = await sqrtPriceMath.getPriceAfterSwap(
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1),
        expandTo18Decimals(1).div(10),
        false
      )
      expect(sqrtQ).to.eq(encodePriceSqrt(121, 100))
    })
    it('price of 1 to 1/1.21', async () => {
      const sqrtQ = await sqrtPriceMath.getPriceAfterSwap(
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1),
        expandTo18Decimals(1).div(10),
        true
      )
      expect(sqrtQ).to.eq(encodePriceSqrt(100, 121))
    })
  })

  describe('#getAmountDeltas', () => {
    it('throws if either price is 0', async () => {
      await expect(sqrtPriceMath.getAmountDeltas(0, encodePriceSqrt(1, 1), 1)).to.be.revertedWith(
        'SqrtPriceMath::getAmountDeltas: price cannot be 0'
      )
      await expect(sqrtPriceMath.getAmountDeltas(encodePriceSqrt(1, 1), 0, 1)).to.be.revertedWith(
        'SqrtPriceMath::getAmountDeltas: price cannot be 0'
      )
    })
    it('returns 0 if liquidity is 0', async () => {
      const {amount0, amount1} = await sqrtPriceMath.getAmountDeltas(encodePriceSqrt(1, 1), encodePriceSqrt(2, 1), 0)
      expect(amount0).to.eq(0)
      expect(amount1).to.eq(0)
    })
    it('returns 0 if prices are equal', async () => {
      const {amount0, amount1} = await sqrtPriceMath.getAmountDeltas(
        encodePriceSqrt(1, 1),
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1)
      )
      expect(amount0).to.eq(0)
      expect(amount1).to.eq(0)
    })
    it('returns positive amount1 and negative amount0 for increasing price', async () => {
      const {amount0, amount1} = await sqrtPriceMath.getAmountDeltas(
        encodePriceSqrt(1, 1),
        encodePriceSqrt(2, 1),
        expandTo18Decimals(1)
      )
      expect(amount0).to.be.lt(0)
      expect(amount1).to.be.gt(0)
    })
    it('returns negative amount1 and positive amount0 for decreasing price', async () => {
      const {amount0, amount1} = await sqrtPriceMath.getAmountDeltas(
        encodePriceSqrt(2, 1),
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1)
      )
      expect(amount0).to.be.gt(0)
      expect(amount1).to.be.lt(0)
    })
    it('returns 0.1 amount1 for price of 1 to 1.21', async () => {
      const {amount0, amount1} = await sqrtPriceMath.getAmountDeltas(
        encodePriceSqrt(1, 1),
        encodePriceSqrt(121, 100),
        expandTo18Decimals(1)
      )
      expect(amount0).to.eq('-90909090909090910')
      expect(amount1).to.eq('99999999999999999')
    })
    it('returns 0.1 amount0 for price of 1 to 1/1.21', async () => {
      const {amount0, amount1} = await sqrtPriceMath.getAmountDeltas(
        encodePriceSqrt(1, 1),
        encodePriceSqrt(100, 121),
        expandTo18Decimals(1)
      )
      expect(amount0).to.eq('100000000000000000')
      expect(amount1).to.eq('-90909090909090909')
    })
  })
})
