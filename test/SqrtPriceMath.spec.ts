import {BigNumber} from 'ethers'
import {ethers} from 'hardhat'
import {SqrtPriceMathTest} from '../typechain/SqrtPriceMathTest'

import {expect} from './shared/expect'
import {encodePriceSqrt, expandTo18Decimals} from './shared/utilities'

describe.only('SqrtPriceMath', () => {
  let sqrtPriceMath: SqrtPriceMathTest
  before(async () => {
    const priceMathTestFactory = await ethers.getContractFactory('SqrtPriceMathTest')
    sqrtPriceMath = (await priceMathTestFactory.deploy()) as SqrtPriceMathTest
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
})
