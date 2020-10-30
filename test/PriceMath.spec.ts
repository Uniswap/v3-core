import {Contract, BigNumber} from 'ethers'
import {waffle} from '@nomiclabs/buidler'

import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {encodePrice, expandTo18Decimals} from './shared/utilities'

import PriceMathTest from '../build/PriceMathTest.json'
import TickMathTest from '../build/TickMathTest.json'

describe('PriceMath', () => {
  const [wallet] = waffle.provider.getWallets()
  const deployContract = waffle.deployContract

  let priceMath: Contract
  let tickMath: Contract
  beforeEach(async () => {
    priceMath = await deployContract(wallet, PriceMathTest, [])
    tickMath = await deployContract(wallet, TickMathTest, [])
  })

  describe('#getInputToRatio', () => {
    describe('edge cases', () => {
      it('0 all', async () => {
        await expect(priceMath.getInputToRatio(0, 0, 0, [0], [0], true)).to.be.revertedWith('FixedPoint: DIV_BY_ZERO')
        await expect(priceMath.getInputToRatio(0, 0, 0, [0], [0], false)).to.be.revertedWith('FixedPoint: DIV_BY_ZERO')
      })

      it('returns 0 if wrong direction', async () => {
        // no amount in will move the ratio of reserve in/reserve out from 1:50 to 1:75
        const price = expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(75))
        expect(
          await priceMath.getInputToRatio(
            expandTo18Decimals(1),
            expandTo18Decimals(50),
            30,
            [price],
            [BigNumber.from(2).pow(224).div(price)],
            false
          )
        ).to.eq('0')
      })

      it('returns 0 if price is equal', async () => {
        const price = expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(50))

        expect(
          await priceMath.getInputToRatio(
            expandTo18Decimals(1),
            expandTo18Decimals(50),
            30,
            [price],
            [BigNumber.from(2).pow(224).div(price)],
            false
          )
        ).to.eq('0')
      })

      it('gas: returns 0 if price is equal', async () => {
        const price = expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(50))

        await snapshotGasCost(
          priceMath.getGasCostOfGetInputToRatio(
            expandTo18Decimals(1),
            expandTo18Decimals(50),
            3000,
            [price],
            [BigNumber.from(2).pow(224).div(price)],
            false
          )
        )
      })
    })

    describe('1:100 to 1:50 at 30bps', () => {
      it('returns 414835953198742784', async () => {
        const price = expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(50))
        expect(
          await priceMath.getInputToRatio(
            expandTo18Decimals(1),
            expandTo18Decimals(100),
            30,
            [price],
            [BigNumber.from(2).pow(224).div(price)],
            false
          )
          // TODO redo this?
          // close but not exact
          // https://www.wolframalpha.com/input/?i=solve+%28x0+%2B+x%29+%2F+%28%28y0+*+x0%29+%2F+%28x0+%2B+x+*+%281-f%29%29%29+%3D+p+for+x+where+x0+%3D+1e18+and+y0+%3D+1e20+and+f+%3D+0.003+and+p+%3D+1%2F50
        ).to.eq('414835953198742811')
      })
      it('verify result', () => {
        const amountIn = BigNumber.from('414835953198742811')
        const amountInWithoutFee = amountIn.mul(997).div(1000)
        const reserveInAfter = expandTo18Decimals(1).add(amountIn)
        const reserveOutAfter = expandTo18Decimals(1)
          .mul(expandTo18Decimals(100))
          .div(expandTo18Decimals(1).add(amountInWithoutFee))
        const ratioAfter = reserveInAfter.mul(BigNumber.from(2).pow(112)).div(reserveOutAfter)

        const targetRatio = expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(50))
        // a difference of lte 2^56 in a uq112x112 is <= 2^-56
        expect(ratioAfter.sub(targetRatio).abs()).to.be.lte(BigNumber.from(2).pow(56))
      })
    })

    it('1:100 to 1:50 at 60bps', async () => {
      const price = expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(50))
      expect(
        await priceMath.getInputToRatio(
          expandTo18Decimals(1),
          expandTo18Decimals(100),
          60,
          [price],
          [BigNumber.from(2).pow(224).div(price)],
          false
        )
      ).to.eq('415460493085696915')
    })

    it('1:100 to 1:75 at 45bps', async () => {
      const price = expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(75))
      expect(
        await priceMath.getInputToRatio(
          expandTo18Decimals(1),
          expandTo18Decimals(100),
          45,
          [price],
          [BigNumber.from(2).pow(224).div(price)],
          false
        )
      ).to.eq('155049452346487537')
    })

    describe('echidna edge cases', () => {
      // these edge cases were found by echidna
      for (let {reserveOut, reserveIn, tick, zeroForOne, lpFee} of [
        {
          reserveIn: BigNumber.from('464695615909263721513790873246206'),
          reserveOut: BigNumber.from('269'),
          lpFee: BigNumber.from('758'),
          tick: BigNumber.from('7100'),
          zeroForOne: false,
        },
        {
          reserveIn: BigNumber.from('102'),
          reserveOut: BigNumber.from('726'),
          lpFee: BigNumber.from('1277'),
          tick: BigNumber.from('191'),
          zeroForOne: true,
        },
        {
          reserveIn: BigNumber.from('113'),
          reserveOut: BigNumber.from('880'),
          lpFee: BigNumber.from('19'),
          tick: BigNumber.from('200'),
          zeroForOne: true,
        },
      ]) {
        it(`passes for getInputToRatioAlwaysExceedsNextPrice(${reserveIn.toString()},${reserveOut.toString()},${lpFee.toString()},${tick.toString()},${zeroForOne})`, async () => {
          const [targetPrice, inverseTargetPrice] = await Promise.all([
            tickMath.getPrice(tick),
            tickMath.getPrice(-tick),
          ])
          const amountIn = await priceMath.getInputToRatio(
            reserveIn,
            reserveOut,
            lpFee,
            targetPrice,
            inverseTargetPrice,
            zeroForOne
          )

          const amountOut = await priceMath.getAmountOut(reserveIn, reserveOut, lpFee, amountIn)
          const priceAfterSwap = zeroForOne
            ? encodePrice(reserveOut.sub(amountOut), reserveIn.add(amountIn))
            : encodePrice(reserveIn.add(amountIn), reserveOut.sub(amountOut))

          expect({
            amountIn: amountIn.toString(),
            amountOut: amountOut.toString(),
            targetPrice: targetPrice[0].toString(),
            priceAfter: priceAfterSwap.toString(),
          }).to.matchSnapshot('params')

          if (zeroForOne) expect(priceAfterSwap).to.be.lte(targetPrice[0])
          else expect(priceAfterSwap).to.be.gte(targetPrice[0])

          // check we did not go too far
          if (amountIn.eq(0)) {
            const originalPrice = zeroForOne ? encodePrice(reserveOut, reserveIn) : encodePrice(reserveIn, reserveOut)
            if (zeroForOne) expect(originalPrice).to.be.lt(targetPrice)
            else expect(origin).to.be.gte(targetPrice)
          } else if (amountIn.gt(0)) {
            const [nextTickPrice] = await tickMath.getPrice(zeroForOne ? tick.sub(1) : tick.add(1))

            if (zeroForOne)
              expect(priceAfterSwap, 'price is not past the next (lower) tick price').to.not.be.lte(nextTickPrice)
            else expect(priceAfterSwap, 'price is not past the next (greater) tick price').to.not.be.gte(nextTickPrice)
          }
        })
      }

      // this edge case was found by echidna
      it('can overflow input reserves', async () => {
        const reserveIn = BigNumber.from('5089906573023864621444189161792019')
        const reserveOut = BigNumber.from('4919843886365783878191471555028931')
        const lpFee = BigNumber.from('411')
        const tick = 11
        const zeroForOne = false

        const [price] = await (zeroForOne ? tickMath.getPrice(tick) : tickMath.getPrice(tick + 1))
        const [priceInverse] = await (zeroForOne ? tickMath.getPrice(-tick) : tickMath.getPrice(-(tick + 1)))

        await expect(
          priceMath.getInputToRatio(reserveIn, reserveOut, lpFee, [price], [priceInverse], zeroForOne)
        ).to.be.revertedWith('PriceMath: INPUT_RESERVES_NECESSARILY_OVERFLOW')
      })
    })

    it('gas: 1:100 to 1:75 at 45bps', async () => {
      const price = expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(75))
      await snapshotGasCost(
        priceMath.getGasCostOfGetInputToRatio(
          expandTo18Decimals(1),
          expandTo18Decimals(100),
          45,
          [price],
          [BigNumber.from(2).pow(224).div(price)],
          false
        )
      )
    })
  })
})
