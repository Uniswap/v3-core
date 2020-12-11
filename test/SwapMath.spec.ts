import {ethers} from 'hardhat'
import {SwapMathTest} from '../typechain/SwapMathTest'

import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {encodePriceSqrt, expandTo18Decimals, FeeAmount} from './shared/utilities'

describe('SwapMath', () => {
  let swapMath: SwapMathTest
  before(async () => {
    const swapMathTestFactory = await ethers.getContractFactory('SwapMathTest')
    swapMath = (await swapMathTestFactory.deploy()) as SwapMathTest
  })

  describe('#computeSwapStep', () => {
    it('after swapping amounts, price is price after', async () => {
      const {amountIn, amountOut, priceAfter, feeAmount} = await swapMath.computeSwapStep(
        {_x: encodePriceSqrt(1, 1)},
        {_x: encodePriceSqrt(101, 100)},
        expandTo18Decimals(2),
        expandTo18Decimals(1),
        600,
        false
      )
      expect(amountIn).to.eq('9975124224178054')
      expect(feeAmount).to.eq('5988667735148')
      expect(amountOut).to.eq('9925619580021728')
      expect(priceAfter._x).to.eq('18538748355542988169')
    })

    it('example from failing test', async () => {
      const {amountIn, amountOut, priceAfter, feeAmount} = await swapMath.computeSwapStep(
        {_x: '47108085314816337'},
        {_x: '44377947312771397'},
        '250000000000000001',
        '999999999999999607',
        FeeAmount.MEDIUM,
        true
      )
      expect(amountIn).to.eq('996999999999998211')
      expect(feeAmount).to.eq('3000000000001396')
      expect(amountOut).to.eq('6436444186929')
      expect(priceAfter._x).to.eq('46633159560172327')
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
