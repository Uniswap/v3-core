import {BigNumber} from 'ethers'
import {ethers} from 'hardhat'
import {SwapMathTest} from '../typechain/SwapMathTest'

import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {encodePriceSqrt, expandTo18Decimals, FeeAmount} from './shared/utilities'
import {SqrtPriceMathTest} from '../typechain/SqrtPriceMathTest'

describe('SwapMath', () => {
  let swapMath: SwapMathTest
  let sqrtPriceMath: SqrtPriceMathTest
  before(async () => {
    const swapMathTestFactory = await ethers.getContractFactory('SwapMathTest')
    const sqrtPriceMathTestFactory = await ethers.getContractFactory('SqrtPriceMathTest')
    swapMath = (await swapMathTestFactory.deploy()) as SwapMathTest
    sqrtPriceMath = (await sqrtPriceMathTestFactory.deploy()) as SqrtPriceMathTest
  })

  describe('#computeSwapStep', () => {
    it('exact amount in that gets capped at price target in one for zero', async () => {
      const price = {_x: encodePriceSqrt(1, 1)}
      const priceTarget = {_x: encodePriceSqrt(101, 100)}
      const liquidity = expandTo18Decimals(2)
      const amount = expandTo18Decimals(1)
      const fee = 600
      const zeroForOne = false

      const {amountIn, amountOut, priceAfter, feeAmount} = await swapMath.computeSwapStep(
        price,
        priceTarget,
        liquidity,
        amount,
        fee,
        zeroForOne
      )

      expect(amountIn).to.eq('9975124224178055')
      expect(feeAmount).to.eq('5988667735148')
      expect(amountOut).to.eq('9925619580021728')
      expect(amountIn.add(feeAmount), 'entire amount is not used').to.lt(amount)

      const priceAfterWholeInputAmount = await sqrtPriceMath.getNextPriceFromInput(price, liquidity, amount, zeroForOne)

      expect(priceAfter._x, 'price is capped at price target').to.eq(priceTarget._x)
      expect(priceAfter._x, 'price is less than price after whole input amount').to.lt(priceAfterWholeInputAmount._x)
    })

    it('exact amount in that fully spent in one for zero', async () => {
      const price = {_x: encodePriceSqrt(1, 1)}
      const priceTarget = {_x: encodePriceSqrt(1000, 100)}
      const liquidity = expandTo18Decimals(2)
      const amount = expandTo18Decimals(1)
      const fee = 600
      const zeroForOne = false

      const {amountIn, amountOut, priceAfter, feeAmount} = await swapMath.computeSwapStep(
        price,
        priceTarget,
        liquidity,
        amount,
        fee,
        zeroForOne
      )

      expect(amountIn).to.eq('999400000000000000')
      expect(feeAmount).to.eq('600000000000000')
      expect(amountOut).to.eq('666399946655997866')
      expect(amountIn.add(feeAmount), 'entire amount is used').to.eq(amount)

      const priceAfterWholeInputAmount = await sqrtPriceMath.getNextPriceFromInput(price, liquidity, amount, zeroForOne)

      expect(priceAfter._x, 'price does not reach price target').to.be.lt(priceTarget._x)
      expect(priceAfter._x, 'price is less than price after whole input amount').to.be.lt(priceAfterWholeInputAmount._x)
    })

    it('example from failing test', async () => {
      const {amountIn, amountOut, priceAfter, feeAmount} = await swapMath.computeSwapStep(
        {_x: BigNumber.from('47108085314816337').shl(32)},
        {_x: BigNumber.from('44377947312771397').shl(32)},
        '250000000000000001',
        '999999999999999607',
        FeeAmount.MEDIUM,
        true
      )
      expect(amountIn).to.eq('996999999999999608')
      expect(feeAmount).to.eq('2999999999999999')
      expect(amountOut).to.eq('6436444186929')
      expect(priceAfter._x).to.eq('200287895220089885758853514')
    })

    it('price can decrease from input price', async () => {
      const {amountIn, amountOut, priceAfter, feeAmount} = await swapMath.computeSwapStep(
        {_x: '2413'},
        {_x: '79887613182836312'},
        '1985041575832132834610021537970',
        '10',
        1872,
        false
      )
      expect(amountIn).to.eq('0')
      expect(feeAmount).to.eq('10')
      expect(amountOut).to.eq('0')
      expect(priceAfter._x).to.eq('2413')
    })

    it('gas', async () => {
      await snapshotGasCost(
        swapMath.getGasCostOfComputeSwapStep(
          {_x: encodePriceSqrt(1, 1)},
          {_x: encodePriceSqrt(101, 100)},
          expandTo18Decimals(2),
          expandTo18Decimals(1),
          600,
          false
        )
      )
    })
  })
})
