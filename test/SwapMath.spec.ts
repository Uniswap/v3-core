import {ethers} from 'hardhat'
import {SwapMathTest} from '../typechain/SwapMathTest'

import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {encodePrice, expandTo18Decimals, FeeAmount} from './shared/utilities'

describe('SwapMath', () => {
  let swapMath: SwapMathTest
  before(async () => {
    const swapMathTestFactory = await ethers.getContractFactory('SwapMathTest')
    swapMath = (await swapMathTestFactory.deploy()) as SwapMathTest
  })

  describe('#computeSwap', () => {
    it('after swapping amounts, price is price after', async () => {
      const {amountIn, amountOut, priceAfter} = await swapMath.computeSwap(
        {_x: encodePrice(1, 1)},
        {_x: encodePrice(101, 100)},
        expandTo18Decimals(2),
        expandTo18Decimals(1),
        600,
        false
      )
      expect(amountIn).to.eq('9981112891913202')
      expect(amountOut).to.eq('9925619580021728')
      expect(priceAfter._x).to.eq('343685190590147848098008353506085893570')
    })

    it('example from failing test', async () => {
      const {amountIn, amountOut, priceAfter} = await swapMath.computeSwap(
        {_x: '2219171702028014642662800529861298'},
        {_x: '1969402207695114106085949978216997'},
        '250000000000000001',
        '999999999999999607',
        FeeAmount.MEDIUM,
        true
      )
      expect(amountIn).to.eq('999999999999998206')
      expect(amountOut).to.eq('6436444186929')
      expect(priceAfter._x).to.eq('2174651570564491698575021936594929')
    })

    it('gas', async () => {
      await snapshotGasCost(
        swapMath.getGasCostOfComputeSwap(
          {_x: encodePrice(1, 1)},
          {_x: encodePrice(101, 100)},
          expandTo18Decimals(2),
          expandTo18Decimals(1),
          600,
          false
        )
      )
    })
  })
})
