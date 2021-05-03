import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import { SwapMathTest } from '../typechain/SwapMathTest'

import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import { encodePriceSqrt, expandTo18Decimals } from './shared/utilities'
import { SqrtPriceMathTest } from '../typechain/SqrtPriceMathTest'

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
      const price = encodePriceSqrt(1, 1)
      const priceTarget = encodePriceSqrt(101, 100)
      const liquidity = expandTo18Decimals(2)
      const amount = expandTo18Decimals(1)
      const fee = 600
      const zeroForOne = false

      const { amountIn, amountOut, sqrtQ, feeAmount } = await swapMath.computeSwapStep(
        price,
        priceTarget,
        liquidity,
        amount,
        fee
      )

      expect(amountIn).to.eq('9975124224178055')
      expect(feeAmount).to.eq('5988667735148')
      expect(amountOut).to.eq('9925619580021728')
      expect(amountIn.add(feeAmount), 'entire amount is not used').to.lt(amount)

      const priceAfterWholeInputAmount = await sqrtPriceMath.getNextSqrtPriceFromInput(
        price,
        liquidity,
        amount,
        zeroForOne
      )

      expect(sqrtQ, 'price is capped at price target').to.eq(priceTarget)
      expect(sqrtQ, 'price is less than price after whole input amount').to.lt(priceAfterWholeInputAmount)
    })

    it('exact amount out that gets capped at price target in one for zero', async () => {
      const price = encodePriceSqrt(1, 1)
      const priceTarget = encodePriceSqrt(101, 100)
      const liquidity = expandTo18Decimals(2)
      const amount = expandTo18Decimals(1).mul(-1)
      const fee = 600
      const zeroForOne = false

      const { amountIn, amountOut, sqrtQ, feeAmount } = await swapMath.computeSwapStep(
        price,
        priceTarget,
        liquidity,
        amount,
        fee
      )

      expect(amountIn).to.eq('9975124224178055')
      expect(feeAmount).to.eq('5988667735148')
      expect(amountOut).to.eq('9925619580021728')
      expect(amountOut, 'entire amount out is not returned').to.lt(amount.mul(-1))

      const priceAfterWholeOutputAmount = await sqrtPriceMath.getNextSqrtPriceFromOutput(
        price,
        liquidity,
        amount.mul(-1),
        zeroForOne
      )

      expect(sqrtQ, 'price is capped at price target').to.eq(priceTarget)
      expect(sqrtQ, 'price is less than price after whole output amount').to.lt(priceAfterWholeOutputAmount)
    })

    it('exact amount in that is fully spent in one for zero', async () => {
      const price = encodePriceSqrt(1, 1)
      const priceTarget = encodePriceSqrt(1000, 100)
      const liquidity = expandTo18Decimals(2)
      const amount = expandTo18Decimals(1)
      const fee = 600
      const zeroForOne = false

      const { amountIn, amountOut, sqrtQ, feeAmount } = await swapMath.computeSwapStep(
        price,
        priceTarget,
        liquidity,
        amount,
        fee
      )

      expect(amountIn).to.eq('999400000000000000')
      expect(feeAmount).to.eq('600000000000000')
      expect(amountOut).to.eq('666399946655997866')
      expect(amountIn.add(feeAmount), 'entire amount is used').to.eq(amount)

      const priceAfterWholeInputAmountLessFee = await sqrtPriceMath.getNextSqrtPriceFromInput(
        price,
        liquidity,
        amount.sub(feeAmount),
        zeroForOne
      )

      expect(sqrtQ, 'price does not reach price target').to.be.lt(priceTarget)
      expect(sqrtQ, 'price is equal to price after whole input amount').to.eq(priceAfterWholeInputAmountLessFee)
    })

    it('exact amount out that is fully received in one for zero', async () => {
      const price = encodePriceSqrt(1, 1)
      const priceTarget = encodePriceSqrt(10000, 100)
      const liquidity = expandTo18Decimals(2)
      const amount = expandTo18Decimals(1).mul(-1)
      const fee = 600
      const zeroForOne = false

      const { amountIn, amountOut, sqrtQ, feeAmount } = await swapMath.computeSwapStep(
        price,
        priceTarget,
        liquidity,
        amount,
        fee
      )

      expect(amountIn).to.eq('2000000000000000000')
      expect(feeAmount).to.eq('1200720432259356')
      expect(amountOut).to.eq(amount.mul(-1))

      const priceAfterWholeOutputAmount = await sqrtPriceMath.getNextSqrtPriceFromOutput(
        price,
        liquidity,
        amount.mul(-1),
        zeroForOne
      )

      expect(sqrtQ, 'price does not reach price target').to.be.lt(priceTarget)
      expect(sqrtQ, 'price is less than price after whole output amount').to.eq(priceAfterWholeOutputAmount)
    })

    it('amount out is capped at the desired amount out', async () => {
      const { amountIn, amountOut, sqrtQ, feeAmount } = await swapMath.computeSwapStep(
        BigNumber.from('417332158212080721273783715441582'),
        BigNumber.from('1452870262520218020823638996'),
        '159344665391607089467575320103',
        '-1',
        1
      )
      expect(amountIn).to.eq('1')
      expect(feeAmount).to.eq('1')
      expect(amountOut).to.eq('1') // would be 2 if not capped
      expect(sqrtQ).to.eq('417332158212080721273783715441581')
    })

    it('target price of 1 uses partial input amount', async () => {
      const { amountIn, amountOut, sqrtQ, feeAmount } = await swapMath.computeSwapStep(
        BigNumber.from('2'),
        BigNumber.from('1'),
        '1',
        '3915081100057732413702495386755767',
        1
      )
      expect(amountIn).to.eq('39614081257132168796771975168')
      expect(feeAmount).to.eq('39614120871253040049813')
      expect(amountIn.add(feeAmount)).to.be.lte('3915081100057732413702495386755767')
      expect(amountOut).to.eq('0')
      expect(sqrtQ).to.eq('1')
    })

    it('entire input amount taken as fee', async () => {
      const { amountIn, amountOut, sqrtQ, feeAmount } = await swapMath.computeSwapStep(
        '2413',
        '79887613182836312',
        '1985041575832132834610021537970',
        '10',
        1872
      )
      expect(amountIn).to.eq('0')
      expect(feeAmount).to.eq('10')
      expect(amountOut).to.eq('0')
      expect(sqrtQ).to.eq('2413')
    })

    it('handles intermediate insufficient liquidity in zero for one exact output case', async () => {
      const sqrtP = BigNumber.from('20282409603651670423947251286016')
      const sqrtPTarget = sqrtP.mul(11).div(10)
      const liquidity = 1024
      // virtual reserves of one are only 4
      // https://www.wolframalpha.com/input/?i=1024+%2F+%2820282409603651670423947251286016+%2F+2**96%29
      const amountRemaining = -4
      const feePips = 3000
      const { amountIn, amountOut, sqrtQ, feeAmount } = await swapMath.computeSwapStep(
        sqrtP,
        sqrtPTarget,
        liquidity,
        amountRemaining,
        feePips
      )
      expect(amountOut).to.eq(0)
      expect(sqrtQ).to.eq(sqrtPTarget)
      expect(amountIn).to.eq(26215)
      expect(feeAmount).to.eq(79)
    })

    it('handles intermediate insufficient liquidity in one for zero exact output case', async () => {
      const sqrtP = BigNumber.from('20282409603651670423947251286016')
      const sqrtPTarget = sqrtP.mul(9).div(10)
      const liquidity = 1024
      // virtual reserves of zero are only 262144
      // https://www.wolframalpha.com/input/?i=1024+*+%2820282409603651670423947251286016+%2F+2**96%29
      const amountRemaining = -263000
      const feePips = 3000
      const { amountIn, amountOut, sqrtQ, feeAmount } = await swapMath.computeSwapStep(
        sqrtP,
        sqrtPTarget,
        liquidity,
        amountRemaining,
        feePips
      )
      expect(amountOut).to.eq(26214)
      expect(sqrtQ).to.eq(sqrtPTarget)
      expect(amountIn).to.eq(1)
      expect(feeAmount).to.eq(1)
    })

    describe('gas', () => {
      it('swap one for zero exact in capped', async () => {
        await snapshotGasCost(
          swapMath.getGasCostOfComputeSwapStep(
            encodePriceSqrt(1, 1),
            encodePriceSqrt(101, 100),
            expandTo18Decimals(2),
            expandTo18Decimals(1),
            600
          )
        )
      })
      it('swap zero for one exact in capped', async () => {
        await snapshotGasCost(
          swapMath.getGasCostOfComputeSwapStep(
            encodePriceSqrt(1, 1),
            encodePriceSqrt(99, 100),
            expandTo18Decimals(2),
            expandTo18Decimals(1),
            600
          )
        )
      })
      it('swap one for zero exact out capped', async () => {
        await snapshotGasCost(
          swapMath.getGasCostOfComputeSwapStep(
            encodePriceSqrt(1, 1),
            encodePriceSqrt(101, 100),
            expandTo18Decimals(2),
            expandTo18Decimals(1).mul(-1),
            600
          )
        )
      })
      it('swap zero for one exact out capped', async () => {
        await snapshotGasCost(
          swapMath.getGasCostOfComputeSwapStep(
            encodePriceSqrt(1, 1),
            encodePriceSqrt(99, 100),
            expandTo18Decimals(2),
            expandTo18Decimals(1).mul(-1),
            600
          )
        )
      })
      it('swap one for zero exact in partial', async () => {
        await snapshotGasCost(
          swapMath.getGasCostOfComputeSwapStep(
            encodePriceSqrt(1, 1),
            encodePriceSqrt(1010, 100),
            expandTo18Decimals(2),
            1000,
            600
          )
        )
      })
      it('swap zero for one exact in partial', async () => {
        await snapshotGasCost(
          swapMath.getGasCostOfComputeSwapStep(
            encodePriceSqrt(1, 1),
            encodePriceSqrt(99, 1000),
            expandTo18Decimals(2),
            1000,
            600
          )
        )
      })
      it('swap one for zero exact out partial', async () => {
        await snapshotGasCost(
          swapMath.getGasCostOfComputeSwapStep(
            encodePriceSqrt(1, 1),
            encodePriceSqrt(1010, 100),
            expandTo18Decimals(2),
            1000,
            600
          )
        )
      })
      it('swap zero for one exact out partial', async () => {
        await snapshotGasCost(
          swapMath.getGasCostOfComputeSwapStep(
            encodePriceSqrt(1, 1),
            encodePriceSqrt(99, 1000),
            expandTo18Decimals(2),
            1000,
            600
          )
        )
      })
    })
  })
})
