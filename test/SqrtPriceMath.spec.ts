import { BigNumber, constants } from 'ethers'
import { ethers } from 'hardhat'
import { SqrtPriceMathTest } from '../typechain/SqrtPriceMathTest'

import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import { encodePriceSqrt, expandTo18Decimals } from './shared/utilities'

describe('SqrtPriceMath', () => {
  let sqrtPriceMath: SqrtPriceMathTest
  before(async () => {
    const sqrtPriceMathTestFactory = await ethers.getContractFactory('SqrtPriceMathTest')
    sqrtPriceMath = (await sqrtPriceMathTestFactory.deploy()) as SqrtPriceMathTest
  })

  describe('#getNextPriceFromInput', () => {
    it('fails if price is zero', async () => {
      await expect(sqrtPriceMath.getNextPriceFromInput(0, 0, expandTo18Decimals(1).div(10), false)).to.be.revertedWith(
        'P'
      )
    })

    it('fails if liquidity is zero', async () => {
      await expect(sqrtPriceMath.getNextPriceFromInput(1, 0, expandTo18Decimals(1).div(10), true)).to.be.revertedWith(
        'L'
      )
    })

    it('fails if input amount overflows the price', async () => {
      const price = BigNumber.from(2).pow(160).sub(1)
      const liquidity = 1024
      const amountIn = 1024
      await expect(sqrtPriceMath.getNextPriceFromInput(price, liquidity, amountIn, false)).to.be.revertedWith('DO')
    })

    it('any input amount cannot underflow the price', async () => {
      const price = 1
      const liquidity = 1
      const amountIn = BigNumber.from(2).pow(255)
      expect(await sqrtPriceMath.getNextPriceFromInput(price, liquidity, amountIn, true)).to.eq(1)
    })

    it('returns input price if amount in is zero and zeroForOne = true', async () => {
      const price = encodePriceSqrt(1, 1)
      expect(await sqrtPriceMath.getNextPriceFromInput(price, expandTo18Decimals(1).div(10), 0, true)).to.eq(price)
    })

    it('returns input price if amount in is zero and zeroForOne = false', async () => {
      const price = encodePriceSqrt(1, 1)
      expect(await sqrtPriceMath.getNextPriceFromInput(price, expandTo18Decimals(1).div(10), 0, false)).to.eq(price)
    })

    it('input amount of 0.1 token1', async () => {
      const sqrtQ = await sqrtPriceMath.getNextPriceFromInput(
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1),
        expandTo18Decimals(1).div(10),
        false
      )
      expect(sqrtQ).to.eq('87150978765690771352898345369')
    })

    it('input amount of 0.1 token0', async () => {
      const sqrtQ = await sqrtPriceMath.getNextPriceFromInput(
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1),
        expandTo18Decimals(1).div(10),
        true
      )
      expect(sqrtQ).to.eq('72025602285694852357767227579')
    })

    it('amountIn > uint96(-1) and zeroForOne = true', async () => {
      expect(
        await sqrtPriceMath.getNextPriceFromInput(
          encodePriceSqrt(1, 1),
          expandTo18Decimals(10),
          BigNumber.from(2).pow(100),
          true
        )
        // perfect answer:
        // https://www.wolframalpha.com/input/?i=624999999995069620+-+%28%281e19+*+1+%2F+%281e19+%2B+2%5E100+*+1%29%29+*+2%5E96%29
      ).to.eq('624999999995069620')
    })

    it('can return 1 with enough amountIn and zeroForOne = true', async () => {
      expect(
        await sqrtPriceMath.getNextPriceFromInput(encodePriceSqrt(1, 1), 1, constants.MaxUint256.div(2), true)
      ).to.eq(1)
    })

    it('zeroForOne = true gas', async () => {
      await snapshotGasCost(
        sqrtPriceMath.getGasCostOfGetNextPriceFromInput(
          encodePriceSqrt(1, 1),
          expandTo18Decimals(1),
          expandTo18Decimals(1).div(10),
          true
        )
      )
    })

    it('zeroForOne = false gas', async () => {
      await snapshotGasCost(
        sqrtPriceMath.getGasCostOfGetNextPriceFromInput(
          encodePriceSqrt(1, 1),
          expandTo18Decimals(1),
          expandTo18Decimals(1).div(10),
          false
        )
      )
    })
  })

  describe('#getNextPriceFromOutput', () => {
    it('fails if price is zero', async () => {
      await expect(sqrtPriceMath.getNextPriceFromOutput(0, 0, expandTo18Decimals(1).div(10), false)).to.be.revertedWith(
        'P'
      )
    })

    it('fails if liquidity is zero', async () => {
      await expect(sqrtPriceMath.getNextPriceFromOutput(1, 0, expandTo18Decimals(1).div(10), true)).to.be.revertedWith(
        'L'
      )
    })

    it('fails if output amount is exactly the virtual reserves of token0', async () => {
      const price = '20282409603651670423947251286016'
      const liquidity = 1024
      const amountOut = 4
      await expect(sqrtPriceMath.getNextPriceFromOutput(price, liquidity, amountOut, false)).to.be.revertedWith('OUT')
    })

    it('fails if output amount is greater than virtual reserves of token0', async () => {
      const price = '20282409603651670423947251286016'
      const liquidity = 1024
      const amountOut = 5
      await expect(sqrtPriceMath.getNextPriceFromOutput(price, liquidity, amountOut, false)).to.be.revertedWith('SO')
    })

    it('succeeds if output amount is exactly the virtual reserves of token1', async () => {
      const price = '20282409603651670423947251286016'
      const liquidity = 1024
      const amountOut = 262144
      // todo: this edge case should probably be handled a little better given 0 is not a real price
      expect(await sqrtPriceMath.getNextPriceFromOutput(price, liquidity, amountOut, true)).to.eq(0)
    })

    it('fails if output amount is greater than virtual reserves of token1', async () => {
      const price = '20282409603651670423947251286016'
      const liquidity = 1024
      const amountOut = 262145
      await expect(sqrtPriceMath.getNextPriceFromOutput(price, liquidity, amountOut, true)).to.be.revertedWith('SO')
    })

    it('puzzling echidna test', async () => {
      const price = '20282409603651670423947251286016'
      const liquidity = 1024
      const amountOut = 4

      await expect(sqrtPriceMath.getNextPriceFromOutput(price, liquidity, amountOut, false)).to.be.reverted
    })

    it('returns input price if amount in is zero and zeroForOne = true', async () => {
      const price = encodePriceSqrt(1, 1)
      expect(await sqrtPriceMath.getNextPriceFromOutput(price, expandTo18Decimals(1).div(10), 0, true)).to.eq(price)
    })

    it('returns input price if amount in is zero and zeroForOne = false', async () => {
      const price = encodePriceSqrt(1, 1)
      expect(await sqrtPriceMath.getNextPriceFromOutput(price, expandTo18Decimals(1).div(10), 0, false)).to.eq(price)
    })

    it('output amount of 0.1 token1', async () => {
      const sqrtQ = await sqrtPriceMath.getNextPriceFromOutput(
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1),
        expandTo18Decimals(1).div(10),
        false
      )
      expect(sqrtQ).to.eq('88031291682515930659493278152')
    })

    it('output amount of 0.1 token1', async () => {
      const sqrtQ = await sqrtPriceMath.getNextPriceFromOutput(
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1),
        expandTo18Decimals(1).div(10),
        true
      )
      expect(sqrtQ).to.eq('71305346262837903834189555302')
    })

    it('reverts if amountOut is impossible in zero for one direction', async () => {
      await expect(
        sqrtPriceMath.getNextPriceFromOutput(encodePriceSqrt(1, 1), 1, constants.MaxUint256, true)
      ).to.be.revertedWith('FMD')
    })

    it('reverts if amountOut is impossible in one for zero direction', async () => {
      await expect(
        sqrtPriceMath.getNextPriceFromOutput(encodePriceSqrt(1, 1), 1, constants.MaxUint256, false)
      ).to.be.revertedWith('SO')
    })

    it('zeroForOne = true gas', async () => {
      await snapshotGasCost(
        sqrtPriceMath.getGasCostOfGetNextPriceFromOutput(
          encodePriceSqrt(1, 1),
          expandTo18Decimals(1),
          expandTo18Decimals(1).div(10),
          true
        )
      )
    })

    it('zeroForOne = false gas', async () => {
      await snapshotGasCost(
        sqrtPriceMath.getGasCostOfGetNextPriceFromOutput(
          encodePriceSqrt(1, 1),
          expandTo18Decimals(1),
          expandTo18Decimals(1).div(10),
          false
        )
      )
    })
  })

  describe('#getAmount0Delta', () => {
    it('reverts if prices have the wrong relation', async () => {
      await expect(sqrtPriceMath.getAmount0Delta(encodePriceSqrt(1, 1).sub(1), encodePriceSqrt(1, 1), 0, true)).to.be
        .reverted
    })
    it('returns 0 if liquidity is 0', async () => {
      const amount0 = await sqrtPriceMath.getAmount0Delta(encodePriceSqrt(2, 1), encodePriceSqrt(1, 1), 0, true)

      expect(amount0).to.eq(0)
    })
    it('returns 0 if prices are equal', async () => {
      const amount0 = await sqrtPriceMath.getAmount0Delta(encodePriceSqrt(1, 1), encodePriceSqrt(1, 1), 0, true)

      expect(amount0).to.eq(0)
    })

    it('returns 0.1 amount1 for price of 1 to 1.21', async () => {
      const amount0 = await sqrtPriceMath.getAmount0Delta(
        encodePriceSqrt(121, 100),
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1),
        true
      )
      expect(amount0).to.eq('90909090909090910')

      const amount0RoundedDown = await sqrtPriceMath.getAmount0Delta(
        encodePriceSqrt(121, 100),
        encodePriceSqrt(1, 1),
        expandTo18Decimals(1),
        false
      )

      expect(amount0RoundedDown).to.eq(amount0.sub(1))
    })

    it('works for prices that overflow', async () => {
      const amount0Up = await sqrtPriceMath.getAmount0Delta(
        encodePriceSqrt(BigNumber.from(2).pow(96), 1),
        encodePriceSqrt(BigNumber.from(2).pow(90), 1),
        expandTo18Decimals(1),
        true
      )
      const amount0Down = await sqrtPriceMath.getAmount0Delta(
        encodePriceSqrt(BigNumber.from(2).pow(96), 1),
        encodePriceSqrt(BigNumber.from(2).pow(90), 1),
        expandTo18Decimals(1),
        false
      )
      expect(amount0Up).to.eq(amount0Down.add(1))
    })

    it(`gas cost for amount0 where roundUp = true`, async () => {
      await snapshotGasCost(
        sqrtPriceMath.getGasCostOfGetAmount0Delta(
          encodePriceSqrt(1, 1),
          encodePriceSqrt(100, 121),
          expandTo18Decimals(1),
          true
        )
      )
    })

    it(`gas cost for amount0 where roundUp = true`, async () => {
      await snapshotGasCost(
        sqrtPriceMath.getGasCostOfGetAmount0Delta(
          encodePriceSqrt(1, 1),
          encodePriceSqrt(100, 121),
          expandTo18Decimals(1),
          false
        )
      )
    })
  })

  describe('#getAmount1Delta', () => {
    it('reverts if prices have the wrong relation', async () => {
      await expect(sqrtPriceMath.getAmount1Delta(encodePriceSqrt(1, 1), encodePriceSqrt(1, 1).sub(1), 0, true)).to.be
        .reverted
    })
    it('returns 0 if liquidity is 0', async () => {
      const amount1 = await sqrtPriceMath.getAmount1Delta(encodePriceSqrt(1, 1), encodePriceSqrt(2, 1), 0, true)

      expect(amount1).to.eq(0)
    })
    it('returns 0 if prices are equal', async () => {
      const amount1 = await sqrtPriceMath.getAmount0Delta(encodePriceSqrt(1, 1), encodePriceSqrt(1, 1), 0, true)

      expect(amount1).to.eq(0)
    })

    it('returns 0.1 amount1 for price of 1 to 1.21', async () => {
      const amount1 = await sqrtPriceMath.getAmount1Delta(
        encodePriceSqrt(1, 1),
        encodePriceSqrt(121, 100),
        expandTo18Decimals(1),
        true
      )

      expect(amount1).to.eq('100000000000000000')
      const amount1RoundedDown = await sqrtPriceMath.getAmount1Delta(
        encodePriceSqrt(1, 1),
        encodePriceSqrt(121, 100),
        expandTo18Decimals(1),
        false
      )

      expect(amount1RoundedDown).to.eq(amount1.sub(1))
    })

    it(`gas cost for amount0 where roundUp = true`, async () => {
      await snapshotGasCost(
        sqrtPriceMath.getGasCostOfGetAmount0Delta(
          encodePriceSqrt(1, 1),
          encodePriceSqrt(100, 121),
          expandTo18Decimals(1),
          true
        )
      )
    })

    it(`gas cost for amount0 where roundUp = false`, async () => {
      await snapshotGasCost(
        sqrtPriceMath.getGasCostOfGetAmount0Delta(
          encodePriceSqrt(1, 1),
          encodePriceSqrt(100, 121),
          expandTo18Decimals(1),
          false
        )
      )
    })
  })

  describe('swap computation', () => {
    it('sqrtP * sqrtQ overflows', async () => {
      // getNextPriceInvariants(1025574284609383690408304870162715216695788925244,50015962439936049619261659728067971248,406,true)
      const sqrtP = '1025574284609383690408304870162715216695788925244'
      const liquidity = '50015962439936049619261659728067971248'
      const zeroForOne = true
      const amountIn = '406'

      const sqrtQ = await sqrtPriceMath.getNextPriceFromInput(sqrtP, liquidity, amountIn, zeroForOne)
      expect(sqrtQ).to.eq('1025574284609383582644711336373707553698163132913')

      const amount0Delta = await sqrtPriceMath.getAmount0Delta(sqrtP, sqrtQ, liquidity, true)
      expect(amount0Delta).to.eq('406')
    })
  })
})
