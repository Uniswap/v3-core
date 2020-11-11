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
          priceTarget: BigNumber.from('5296662025391377663863959305437419'),
          reserve0: BigNumber.from(101),
          reserve1: BigNumber.from(102),
          lpFee: 1934,
          zeroForOne: false,
          summary: 'echidna failed test: getInputToRatioInvariants(101,102,1934,2)',
        },
        {
          priceTarget: BigNumber.from('5244219827120175904815801292512296'),
          reserve0: BigNumber.from('44155072587566675454184985'),
          reserve1: BigNumber.from('1420193175776351360096'),
          lpFee: 1,
          zeroForOne: false,
          summary:
            'echidna failed test: getInputToRatioInvariants(44155072587566675454184985,1420193175776351360096,1,1,false)',
        },
        {
          priceTarget: BigNumber.from('5244219827120175904815801292512296'),
          reserve0: BigNumber.from('5253224048874618374'),
          reserve1: BigNumber.from('355610057740100969'),
          lpFee: 1,
          zeroForOne: false,
          summary: 'echidna failed test: getInputToRatioInvariants(5253224048874618374,355610057740100969,1,1,false)',
        },
        {
          priceTarget: BigNumber.from('5244219827120175904815801292512296'),
          reserve0: BigNumber.from('9409237716022133308928237222943'),
          reserve1: BigNumber.from('4473130994246429306704691806449'),
          lpFee: 2,
          zeroForOne: false,
          summary:
            'echidna failed test: getInputToRatioInvariants(9409237716022133308928237222943,4473130994246429306704691806449,2,1,false)',
        },
      ]) {
        describe(summary, () => {
          let priceBeforeSwap: BigNumber
          let amountIn: BigNumber
          let amountInLessFee: BigNumber
          let amountOut: BigNumber
          let amountOutMax: BigNumber
          let priceAfterSwap: BigNumber
          let priceAfterSwapWith1MoreWeiInput: BigNumber

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

            priceAfterSwapWith1MoreWeiInput = zeroForOne
              ? encodePrice(reserve1.sub(amountOut), reserve0.add(amountInLessFee).add(1))
              : encodePrice(reserve1.add(amountInLessFee).add(1), reserve0.sub(amountOut))
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
              priceAfterSwapWith1MoreWeiInput: priceAfterSwapWith1MoreWeiInput.toString(),
            }).to.matchSnapshot()
          })

          it('price moves in the right direction', () => {
            if (zeroForOne) {
              expect(priceAfterSwap).to.be.lte(priceBeforeSwap)
            } else {
              expect(priceAfterSwap).to.be.gte(priceBeforeSwap)
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
              expect(priceAfterSwapWith1MoreWeiInput).to.be.lt(priceTarget)
            } else {
              expect(priceAfterSwapWith1MoreWeiInput).to.be.gt(priceTarget)
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
