import {Contract, BigNumber} from 'ethers'
import {waffle} from '@nomiclabs/buidler'

import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {encodePrice, expandTo18Decimals} from './shared/utilities'

import PriceMathTest from '../build/PriceMathTest.json'

describe('PriceMath', () => {
  const [wallet] = waffle.provider.getWallets()
  const deployContract = waffle.deployContract

  let priceMath: Contract
  before(async () => {
    priceMath = await deployContract(wallet, PriceMathTest, [])
  })

  describe('#getInputToRatio', () => {
    describe('edge cases', () => {
      it('0 all', async () => {
        await expect(priceMath.getInputToRatio(0, 0, 0, [0], true)).to.be.revertedWith('FixedPoint: DIV_BY_ZERO')
        await expect(priceMath.getInputToRatio(0, 0, 0, [0], false)).to.be.revertedWith('FixedPoint: DIV_BY_ZERO')
      })

      it('returns 0 if wrong direction', async () => {
        const price = encodePrice(expandTo18Decimals(75), expandTo18Decimals(1))

        // going from zero to one
        // that means reserve1 will decrease and reserve0 will increase
        // i.e. the price will decrease, so the target price must be lower than the current price
        expect(await priceMath.getInputToRatio(expandTo18Decimals(1), expandTo18Decimals(50), 30, [price], true)).to.eq(
          '0'
        )
      })

      it('returns 0 if price is equal', async () => {
        const price = encodePrice(expandTo18Decimals(50), expandTo18Decimals(1))

        expect(
          await priceMath.getInputToRatio(expandTo18Decimals(1), expandTo18Decimals(50), 30, [price], false)
        ).to.eq('0')
      })

      it('gas: returns 0 if price is equal', async () => {
        const price = encodePrice(expandTo18Decimals(50), expandTo18Decimals(1))

        await snapshotGasCost(
          priceMath.getGasCostOfGetInputToRatio(expandTo18Decimals(1), expandTo18Decimals(50), 3000, [price], false)
        )
      })
    })

    describe('invariants', () => {
      for (const {priceTarget, reserve0, reserve1, lpFee, zeroForOne, summary} of [
        {
          priceTarget: encodePrice(expandTo18Decimals(50), expandTo18Decimals(1)),
          reserve0: BigNumber.from(1000),
          reserve1: BigNumber.from(100000),
          lpFee: 60,
          zeroForOne: true,
          summary: '1:100 to 1:50 at 60bps with small reserves',
        },
        {
          priceTarget: encodePrice(expandTo18Decimals(50), expandTo18Decimals(1)),
          reserve0: expandTo18Decimals(1),
          reserve1: expandTo18Decimals(100),
          lpFee: 60,
          zeroForOne: true,
          summary: '1:100 to 1:50 at 60bps',
        },
        {
          priceTarget: encodePrice(expandTo18Decimals(75), expandTo18Decimals(1)),
          reserve0: expandTo18Decimals(1),
          reserve1: expandTo18Decimals(100),
          lpFee: 45,
          zeroForOne: true,
          summary: '1:100 to 1:75 at 45bps',
        },
        {
          priceTarget: encodePrice(expandTo18Decimals(50), expandTo18Decimals(1)),
          reserve0: expandTo18Decimals(1),
          reserve1: expandTo18Decimals(100),
          lpFee: 30,
          zeroForOne: true,
          summary: '1:100 to 1:50 at 30bps',
        },
        {
          priceTarget: encodePrice(expandTo18Decimals(100), expandTo18Decimals(1)),
          reserve0: expandTo18Decimals(1),
          reserve1: expandTo18Decimals(50),
          lpFee: 200,
          zeroForOne: false,
          summary: '1:50 to 1:100 at 200bps',
        },
        {
          priceTarget: encodePrice(expandTo18Decimals(75), expandTo18Decimals(1)),
          reserve0: expandTo18Decimals(1),
          reserve1: expandTo18Decimals(50),
          lpFee: 60,
          zeroForOne: false,
          summary: '1:50 to 1:75 at 60bps',
        },
      ]) {
        describe(summary, () => {
          let amountIn: BigNumber
          let amountInLessFee: BigNumber
          let amountOut: BigNumber
          let priceBeforeSwap: BigNumber
          let priceAfterSwap: BigNumber
          let amountInPlus1: BigNumber
          let amountInPlus1LessFee: BigNumber
          let amountOutWith1MoreWeiInput: BigNumber
          let priceAfterSwapWith1MoreWeiInput: BigNumber

          async function computeSwapResult(
            amountIn: BigNumber
          ): Promise<{amountOut: BigNumber; priceAfterSwap: BigNumber; amountInLessFee: BigNumber}> {
            const amountInLessFee = amountIn.mul(BigNumber.from(10000).sub(lpFee)).div(BigNumber.from(10000))

            const amountOut = zeroForOne
              ? await priceMath.getAmountOut(reserve0, reserve1, amountInLessFee)
              : await priceMath.getAmountOut(reserve1, reserve0, amountInLessFee)

            const priceAfterSwap = zeroForOne
              ? encodePrice(reserve1.sub(amountOut), reserve0.add(amountInLessFee))
              : encodePrice(reserve1.add(amountInLessFee), reserve0.sub(amountOut))
            return {
              amountOut,
              priceAfterSwap,
              amountInLessFee,
            }
          }

          before('compute swap result', async () => {
            priceBeforeSwap = encodePrice(reserve1, reserve0)

            amountIn = await priceMath.getInputToRatio(reserve0, reserve1, lpFee, [priceTarget], zeroForOne)
            ;({amountOut, priceAfterSwap, amountInLessFee} = await computeSwapResult(amountIn))

            amountInPlus1 = amountIn.add(1)
            ;({
              amountOut: amountOutWith1MoreWeiInput,
              priceAfterSwap: priceAfterSwapWith1MoreWeiInput,
              amountInLessFee: amountInPlus1LessFee,
            } = await computeSwapResult(amountInPlus1))
          })

          it('snapshot', () => {
            // for debugging, store all the calculations
            expect({
              reserve0: reserve0.toString(),
              reserve1: reserve1.toString(),
              lpFee,
              zeroForOne,
              priceTarget: priceTarget.toString(),
              priceBeforeSwap: priceBeforeSwap.toString(),
              priceAfterSwap: priceAfterSwap.toString(),
              amountIn: amountIn.toString(),
              amountInLessFee: amountInLessFee.toString(),
              amountOut: amountOut.toString(),
              amountInPlus1: amountInPlus1.toString(),
              amountInPlus1LessFee: amountInPlus1LessFee.toString(),
              amountOutWith1MoreWeiInput: amountOutWith1MoreWeiInput.toString(),
              priceAfterSwapWith1MoreWeiInput: priceAfterSwapWith1MoreWeiInput.toString(),
            }).to.matchSnapshot()
          })

          it('price moves in the right direction', () => {
            if (zeroForOne) {
              expect(priceBeforeSwap).to.be.gte(priceAfterSwap)
            } else {
              expect(priceBeforeSwap).to.be.lte(priceAfterSwap)
            }
          })

          it('price after swap does not pass price target', () => {
            if (zeroForOne) {
              expect(priceAfterSwap).to.be.gte(priceTarget)
            } else {
              expect(priceAfterSwap).to.be.lte(priceTarget)
            }
          })

          it('1 more wei of input exceeds the next price', async () => {
            if (zeroForOne) {
              expect(priceAfterSwapWith1MoreWeiInput).to.be.lte(priceTarget)
            } else {
              expect(priceAfterSwapWith1MoreWeiInput).to.be.gte(priceTarget)
            }
          })

          it('gas', async () => {
            await snapshotGasCost(
              priceMath.getGasCostOfGetInputToRatio(reserve0, reserve1, lpFee, [priceTarget], zeroForOne)
            )
          })
        })
      }
    })
  })
})
