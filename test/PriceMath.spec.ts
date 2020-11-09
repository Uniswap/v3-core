import {Contract, BigNumber} from 'ethers'
import {waffle} from '@nomiclabs/buidler'

import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {encodePrice, expandTo18Decimals} from './shared/utilities'

import PriceMathTest from '../build/PriceMathTest.json'

describe.only('PriceMath', () => {
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
        const [amountIn] = await priceMath.getInputToRatio(
          expandTo18Decimals(1),
          expandTo18Decimals(50),
          30,
          [price],
          true
        )
        expect(amountIn).to.eq(0)
      })

      it('returns 0 if price is equal', async () => {
        const price = encodePrice(expandTo18Decimals(50), expandTo18Decimals(1))

        const [amountIn] = await priceMath.getInputToRatio(
          expandTo18Decimals(1),
          expandTo18Decimals(50),
          30,
          [price],
          false
        )
        expect(amountIn).to.eq(0)
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
        {
          priceTarget: BigNumber.from('5192296858534827628530496329220096'),
          reserve0: BigNumber.from(101),
          reserve1: BigNumber.from(101),
          lpFee: 32,
          zeroForOne: false,
          summary: 'minimum tokens in both to tick 32 price, no fee',
        },
      ]) {
        describe(summary, () => {
          let priceBeforeSwap: BigNumber
          let amountIn: BigNumber
          let amountInLessFee: BigNumber
          let amountOut: BigNumber
          let amountOutMax: BigNumber
          let priceAfterSwap: BigNumber
          let priceAfterSwapWith1MoreWeiEffectiveInput: BigNumber

          before('compute swap result', async () => {
            priceBeforeSwap = encodePrice(reserve1, reserve0)
            ;[amountIn, amountOutMax] = await priceMath.getInputToRatio(
              reserve0,
              reserve1,
              lpFee,
              [priceTarget],
              zeroForOne
            )
            amountInLessFee = amountIn.mul(BigNumber.from(10000).sub(lpFee)).div(10000)
            amountOut = await (zeroForOne
              ? priceMath.getAmountOut(reserve0, reserve1, amountInLessFee)
              : priceMath.getAmountOut(reserve1, reserve0, amountInLessFee))

            // cap the output amount, if necessary
            if (amountOut.gt(amountOutMax)) amountOut = amountOutMax

            priceAfterSwap = zeroForOne
              ? encodePrice(reserve1.sub(amountOut), reserve0.add(amountInLessFee))
              : encodePrice(reserve1.add(amountInLessFee), reserve0.sub(amountOut))

            const outputFor1MoreWeiInput = await (zeroForOne
              ? priceMath.getAmountOut(reserve0.add(amountInLessFee), reserve1.sub(amountOut), 1)
              : priceMath.getAmountOut(reserve1.add(amountInLessFee), reserve0.sub(amountOut), 1))

            priceAfterSwapWith1MoreWeiEffectiveInput = zeroForOne
              ? encodePrice(reserve1.sub(amountOut).sub(outputFor1MoreWeiInput), reserve0.add(amountInLessFee).add(1))
              : encodePrice(reserve1.add(amountInLessFee).add(1), reserve0.sub(amountOut).sub(outputFor1MoreWeiInput))
          })

          it('snapshot', () => {
            // for debugging, store all the calculations
            expect({
              priceTarget: priceTarget.toString(),
              reserve0: reserve0.toString(),
              reserve1: reserve1.toString(),
              lpFee,
              zeroForOne,
              priceBeforeSwap: priceBeforeSwap.toString(),
              amountIn: amountIn.toString(),
              amountInLessFee: amountInLessFee.toString(),
              amountOut: amountOut.toString(),
              priceAfterSwap: priceAfterSwap.toString(),
              priceAfterSwapWith1MoreWeiEffectiveInput: priceAfterSwapWith1MoreWeiEffectiveInput.toString(),
            }).to.matchSnapshot()
          })

          it('price moves in the right direction', () => {
            if (zeroForOne) {
              expect(priceAfterSwap).to.be.lt(priceBeforeSwap)
            } else {
              expect(priceAfterSwap).to.be.gt(priceBeforeSwap)
            }
          })

          it('price after swap does not pass price target', () => {
            if (zeroForOne) {
              expect(priceAfterSwap).to.be.gte(priceTarget)
            } else {
              expect(priceAfterSwap).to.be.lte(priceTarget)
            }
          })

          it('1 more wei of effective input exceeds the next price', async () => {
            if (zeroForOne) {
              expect(priceAfterSwapWith1MoreWeiEffectiveInput).to.be.lt(priceTarget)
            } else {
              expect(priceAfterSwapWith1MoreWeiEffectiveInput).to.be.gt(priceTarget)
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
