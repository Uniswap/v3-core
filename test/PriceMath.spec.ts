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
      const LP_FEE_BASE = BigNumber.from(10000)
      // these edge cases were found by echidna
      for (let {reserveOut, reserveIn, inOutRatio, lpFee} of [
        {
          reserveIn: BigNumber.from('1040'),
          reserveOut: BigNumber.from('1090214879718873987679620123847534'),
          lpFee: BigNumber.from('174'),
          inOutRatio: BigNumber.from('5590'),
        },
        {
          reserveIn: BigNumber.from('1005'),
          reserveOut: BigNumber.from('1137'),
          lpFee: BigNumber.from('1'),
          inOutRatio: BigNumber.from('10447815210759932949745600021781164648681654221105666413902984560'),
        },
        {
          reserveIn: BigNumber.from('123'),
          reserveOut: BigNumber.from('1953579828864582940591891444058760'),
          lpFee: BigNumber.from('6'),
          inOutRatio: BigNumber.from('354'),
        },
        {
          reserveIn: BigNumber.from('15944303097720152669124120417149'),
          reserveOut: BigNumber.from('102'),
          lpFee: BigNumber.from('1'),
          inOutRatio: BigNumber.from('828057777287919958470307583336398120126455251994321806143774553'),
        },
      ]) {
        it(`passes for getInputToRatioAlwaysExceedsNextPrice(${reserveIn.toString()},${reserveOut.toString()},${lpFee.toString()},${inOutRatio.toString()})`, async () => {
          const amountIn = await priceMath.getInputToRatio(
            reserveIn,
            reserveOut,
            lpFee,
            [inOutRatio],
            [BigNumber.from(2).pow(224).div(inOutRatio)],
            false
          )

          expect(amountIn.toString()).to.matchSnapshot('computed amount in')
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
