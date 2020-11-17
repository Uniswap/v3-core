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
        expect(await priceMath.getInputToRatio(0, 0, 0, [0], 0, true)).to.be.deep.eq([
          BigNumber.from(0),
          BigNumber.from(0),
        ])
        expect(await priceMath.getInputToRatio(0, 0, 0, [0], 0, false)).to.be.deep.eq([
          BigNumber.from(0),
          BigNumber.from(0),
        ])
      })

      it('can round poorly', async () => {
        const price = BigNumber.from('4294967297')
        const liquidity = BigNumber.from('18446744073709551615')

        const [amount0Up, amount1Up] = await priceMath.getValueAtPriceRoundingUp([price], liquidity)
        const [amount0Down, amount1Down] = await priceMath.getValueAtPriceRoundingDown([price], liquidity)

        expect(amount0Up).to.be.gte(amount0Down)
        expect(amount1Up).to.be.gte(amount1Down)

        expect(amount0Up.sub(amount0Down)).to.be.eq(2)
        expect(amount1Up.sub(amount1Down)).to.be.eq(1)
      })

      it('returns 0 if price is equal', async () => {
        const liquidity = expandTo18Decimals(10)
        const price = encodePrice(expandTo18Decimals(100), expandTo18Decimals(1))

        const [reserve0, reserve1] = await priceMath.getValueAtPriceRoundingDown([price], liquidity)

        expect(reserve0).to.be.eq(expandTo18Decimals(1))
        expect(reserve1).to.be.eq(expandTo18Decimals(100))

        const [amountIn, amountOut] = await priceMath.getInputToRatio(
          expandTo18Decimals(1),
          expandTo18Decimals(100),
          liquidity,
          [price],
          30,
          false
        )
        expect(amountIn).to.eq(0)
        expect(amountOut).to.eq(0)
      })

      it('gas: returns 0 if price is equal', async () => {
        const liquidity = expandTo18Decimals(10)
        const price = encodePrice(expandTo18Decimals(100), expandTo18Decimals(1))

        await snapshotGasCost(
          priceMath.getGasCostOfGetInputToRatio(
            expandTo18Decimals(1),
            expandTo18Decimals(100),
            liquidity,
            [price],
            30,
            false
          )
        )
      })
    })

    describe('invariants', () => {
      for (const {liquidity, priceStarting, priceTarget, lpFee, zeroForOne, summary} of [
        {
          liquidity: expandTo18Decimals(10000),
          priceStarting: encodePrice(expandTo18Decimals(100000), expandTo18Decimals(1000)),
          priceTarget: encodePrice(expandTo18Decimals(50), expandTo18Decimals(1)),
          lpFee: 60,
          zeroForOne: true,
          summary: '1:100 to 1:50 at 60bps with small reserves',
        },
        {
          liquidity: expandTo18Decimals(10),
          priceStarting: encodePrice(expandTo18Decimals(100), expandTo18Decimals(1)),
          priceTarget: encodePrice(expandTo18Decimals(50), expandTo18Decimals(1)),
          lpFee: 60,
          zeroForOne: true,
          summary: '1:100 to 1:50 at 60bps',
        },
        {
          liquidity: expandTo18Decimals(10),
          priceStarting: encodePrice(expandTo18Decimals(100), expandTo18Decimals(1)),
          priceTarget: encodePrice(expandTo18Decimals(75), expandTo18Decimals(1)),
          lpFee: 45,
          zeroForOne: true,
          summary: '1:100 to 1:75 at 45bps',
        },
        {
          liquidity: expandTo18Decimals(10),
          priceStarting: encodePrice(expandTo18Decimals(100), expandTo18Decimals(1)),
          priceTarget: encodePrice(expandTo18Decimals(50), expandTo18Decimals(1)),
          lpFee: 30,
          zeroForOne: true,
          summary: '1:100 to 1:50 at 30bps',
        },
        {
          liquidity: expandTo18Decimals(7),
          priceStarting: encodePrice(expandTo18Decimals(49), expandTo18Decimals(1)),
          priceTarget: encodePrice(expandTo18Decimals(100), expandTo18Decimals(1)),
          lpFee: 200,
          zeroForOne: false,
          summary: '1:49 to 1:100 at 200bps',
        },
        {
          liquidity: expandTo18Decimals(7),
          priceStarting: encodePrice(expandTo18Decimals(49), expandTo18Decimals(1)),
          priceTarget: encodePrice(expandTo18Decimals(75), expandTo18Decimals(1)),
          lpFee: 60,
          zeroForOne: false,
          summary: '1:49 to 1:75 at 60bps',
        },
      ]) {
        describe(summary, () => {
          let reserve0: BigNumber
          let reserve1: BigNumber
          let amountIn: BigNumber
          let amountOutMax: BigNumber
          let amountInLessFee: BigNumber
          let amountOut: BigNumber
          let priceAfterSwap: BigNumber

          before('compute swap result', async () => {
            ;[reserve0, reserve1] = await priceMath.getValueAtPriceRoundingDown([priceStarting], liquidity)
            ;[amountIn, amountOutMax] = await priceMath.getInputToRatio(
              reserve0,
              reserve1,
              liquidity,
              [priceTarget],
              lpFee,
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
          })

          it('snapshot', () => {
            // for debugging, store all the calculations
            expect({
              reserve0: reserve0.toString(),
              reserve1: reserve1.toString(),
              amountIn: amountIn.toString(),
              amountOutMax: amountOut.toString(),
              amountInLessFee: amountInLessFee.toString(),
              amountOut: amountOut.toString(),
              priceAfterSwap: priceAfterSwap.toString(),
            }).to.matchSnapshot()
          })

          it('zeroForOne is correct', () => {
            if (priceStarting.gte(priceTarget)) {
              expect(zeroForOne).to.be.true
            } else {
              expect(zeroForOne).to.be.false
            }
          })

          it('price moves in the right direction', () => {
            if (zeroForOne) {
              expect(priceAfterSwap).to.be.lte(priceStarting)
            } else {
              expect(priceAfterSwap).to.be.gte(priceStarting)
            }
          })

          // TODO this isn't always true, we have to cap the price
          it.skip('price after swap does not pass price target', () => {
            if (zeroForOne) {
              expect(priceAfterSwap).to.be.gte(priceTarget)
            } else {
              expect(priceAfterSwap).to.be.lte(priceTarget)
            }
          })

          it('gas', async () => {
            await snapshotGasCost(
              priceMath.getGasCostOfGetInputToRatio(reserve0, reserve1, liquidity, [priceTarget], lpFee, zeroForOne)
            )
          })
        })
      }
    })
  })
})
