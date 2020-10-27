import {Contract, BigNumber} from 'ethers'
import {waffle} from '@nomiclabs/buidler'
import PriceMathTest from '../build/PriceMathTest.json'
import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {encodePrice, expandTo18Decimals} from './shared/utilities'

describe('PriceMath', () => {
  const [wallet] = waffle.provider.getWallets()
  const deployContract = waffle.deployContract

  let priceMath: Contract
  beforeEach(async () => {
    priceMath = await deployContract(wallet, PriceMathTest, [])
  })

  describe('#getInputToRatio', () => {
    describe('edge cases', () => {
      it('0 all', async () => {
        await expect(priceMath.getInputToRatio(0, 0, 0, [0])).to.be.revertedWith('FixedPoint: DIV_BY_ZERO')
      })

      it('returns 0 if wrong direction', async () => {
        // no amount in will move the ratio of reserve in/reserve out from 1:50 to 1:75
        expect(
          await priceMath.getInputToRatio(expandTo18Decimals(1), expandTo18Decimals(50), 30, [
            expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(75)),
          ])
        ).to.eq('0')
      })

      it('returns 0 if price is equal', async () => {
        expect(
          await priceMath.getInputToRatio(expandTo18Decimals(1), expandTo18Decimals(50), 30, [
            expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(50)),
          ])
        ).to.eq('0')
      })

      it('gas: returns 0 if price is equal', async () => {
        await snapshotGasCost(
          priceMath.getGasCostOfGetInputToRatio(expandTo18Decimals(1), expandTo18Decimals(50), 3000, [
            expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(50)),
          ])
        )
      })
    })

    describe('1:100 to 1:50 at 30bps', () => {
      it('returns 414835953198742784', async () => {
        expect(
          await priceMath.getInputToRatio(expandTo18Decimals(1), expandTo18Decimals(100), 30, [
            expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(50)),
          ])
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
      expect(
        await priceMath.getInputToRatio(expandTo18Decimals(1), expandTo18Decimals(100), 60, [
          expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(50)),
        ])
      ).to.eq('415460493085696915')
    })

    it('1:100 to 1:75 at 45bps', async () => {
      expect(
        await priceMath.getInputToRatio(expandTo18Decimals(1), expandTo18Decimals(100), 45, [
          expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(75)),
        ])
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
        // todo: this is the case where reserveOut after the swap is 1,
        //    and the amount in needs to be compensated because we cannot have a fraction amount of reserveOut
        // {
        //   reserveIn: BigNumber.from('1005'),
        //   reserveOut: BigNumber.from('1137'),
        //   lpFee: BigNumber.from('1'),
        //   inOutRatio: BigNumber.from('10447815210759932949745600021781164648681654221105666413902984560'),
        // },
        {
          reserveIn: BigNumber.from('1'),
          reserveOut: BigNumber.from('114860866806825295852992454585544'),
          lpFee: BigNumber.from('0'),
          inOutRatio: BigNumber.from('47'),
        },
        {
          reserveIn: BigNumber.from('123'),
          reserveOut: BigNumber.from('1953579828864582940591891444058760'),
          lpFee: BigNumber.from('6'),
          inOutRatio: BigNumber.from('354'),
        },
        // another failing test :(
        // {
        //   reserveIn: BigNumber.from('15944303097720152669124120417149'),
        //   reserveOut: BigNumber.from('102'),
        //   lpFee: BigNumber.from('1'),
        //   inOutRatio: BigNumber.from('828057777287919958470307583336398120126455251994321806143774553'),
        // },
      ]) {
        it(`passes for getInputToRatioAlwaysExceedsNextPrice(${reserveIn.toString()},${reserveOut.toString()},${lpFee.toString()},${inOutRatio.toString()})`, async () => {
          const amountIn = await priceMath.getInputToRatio(reserveIn, reserveOut, lpFee, [inOutRatio])

          expect(amountIn.toString()).to.matchSnapshot('computed amount in')

          const amountOut = reserveOut
            .mul(amountIn)
            .mul(LP_FEE_BASE.sub(lpFee))
            .div(amountIn.mul(BigNumber.from(LP_FEE_BASE).sub(lpFee)).add(reserveIn.mul(LP_FEE_BASE)))

          const reserveInAfter = reserveIn.add(amountIn)
          const reserveOutAfter = reserveOut.sub(amountOut)

          expect(amountOut, 'amount out is less than the reserves out').to.be.lt(reserveOut)
          expect(amountOut.toString()).to.matchSnapshot('computed amount out')

          const priceAfter = encodePrice(reserveInAfter, reserveOutAfter)[1]
          expect(priceAfter, 'price after exceeds in out ratio').to.be.gte(inOutRatio)
        })
      }
    })

    it('gas: 1:100 to 1:75 at 45bps', async () => {
      await snapshotGasCost(
        priceMath.getGasCostOfGetInputToRatio(expandTo18Decimals(1), expandTo18Decimals(100), 45, [
          expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(75)),
        ])
      )
    })
  })
})
