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
      ]) {
        describe(summary, () => {
          let amountIn: BigNumber
          let amountInLessFee: BigNumber
          let amountOut: BigNumber
          let priceAfterSwap: BigNumber
          let amountInLessFeePlus1: BigNumber
          let amountOutWith1MoreWeiInput: BigNumber
          let priceWithOneMoreInput: BigNumber

          before('compute swap result', async () => {
            amountIn = await priceMath.getInputToRatio(reserve0, reserve1, lpFee, [priceTarget], zeroForOne)

            amountInLessFee = amountIn.mul(BigNumber.from(10000).sub(lpFee)).div(BigNumber.from(10000))
            amountOut = zeroForOne
              ? await priceMath.getAmountOut(reserve0, reserve1, amountInLessFee)
              : await priceMath.getAmountOut(reserve1, reserve0, amountInLessFee)

            priceAfterSwap = zeroForOne
              ? encodePrice(reserve1.sub(amountOut), reserve0.add(amountInLessFee))
              : encodePrice(reserve1.add(amountInLessFee), reserve0.sub(amountOut))

            // if we had 1 more wei of input
            amountInLessFeePlus1 = amountInLessFee.add(1)
            amountOutWith1MoreWeiInput = zeroForOne
              ? await priceMath.getAmountOut(reserve0, reserve1, amountInLessFeePlus1)
              : await priceMath.getAmountOut(reserve1, reserve0, amountInLessFeePlus1)
            priceWithOneMoreInput = zeroForOne
              ? encodePrice(reserve1.sub(amountOutWith1MoreWeiInput), reserve0.add(amountInLessFeePlus1))
              : encodePrice(reserve1.add(amountInLessFeePlus1), reserve0.sub(amountOutWith1MoreWeiInput))
          })

          it('snapshot', () => {
            // for debugging, store all the calculations
            expect({
              reserve0: reserve0.toString(),
              reserve1: reserve1.toString(),
              lpFee,
              zeroForOne,
              priceTarget: priceTarget.toString(),
              priceAfterSwap: priceAfterSwap.toString(),
              amountIn: amountIn.toString(),
              amountInLessFee: amountInLessFee.toString(),
              amountOut: amountOut.toString(),
              amountInLessFeePlus1: amountInLessFeePlus1.toString(),
              amountOutWith1MoreWeiInput: amountOutWith1MoreWeiInput.toString(),
              priceWithOneMoreInput: priceWithOneMoreInput.toString(),
            }).to.matchSnapshot()
          })

          it('new price does not exceed price target', async () => {
            if (zeroForOne) {
              expect(priceAfterSwap).to.be.gte(priceTarget)
            } else {
              expect(priceAfterSwap).to.be.lte(priceTarget)
            }
          })

          it('1 more wei of input exceeds the next price', async () => {
            if (zeroForOne) {
              expect(priceWithOneMoreInput).to.be.lte(priceTarget)
            } else {
              expect(priceWithOneMoreInput).to.be.gte(priceTarget)
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
