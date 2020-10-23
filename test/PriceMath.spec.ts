import {Contract, BigNumber} from 'ethers'
import {waffle} from '@nomiclabs/buidler'
import PriceMathTest from '../build/PriceMathTest.json'
import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'
import {expandTo18Decimals} from './shared/utilities'

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
        ).to.eq('414835953198742810')
      })
      it('verify result', () => {
        const amountIn = BigNumber.from('414835953198742810')
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
      ).to.eq('415460493085696914')
    })

    it('1:100 to 1:75 at 45bps', async () => {
      expect(
        await priceMath.getInputToRatio(expandTo18Decimals(1), expandTo18Decimals(100), 45, [
          expandTo18Decimals(1).mul(BigNumber.from(2).pow(112)).div(expandTo18Decimals(75)),
        ])
      ).to.eq('155049452346487536')
    })

    it.only('failing echidna', async () => {
      const reserveIn = BigNumber.from('1040')
      const reserveOut = BigNumber.from('1090214879718873987679620123847534')
      const k = reserveOut.mul(reserveIn)
      const lpFee = BigNumber.from('174')
      const inOutRatio = BigNumber.from('5590')
      const amountIn = await priceMath.getInputToRatio(reserveIn, reserveOut, lpFee, [inOutRatio])

      expect(amountIn).to.eq('65')
      const amountInLessFee = amountIn.mul(BigNumber.from(10_000).sub(lpFee)).div(BigNumber.from(10_000))
      expect(amountInLessFee).to.eq('63')
      const reserveInAfter = reserveIn.add(amountInLessFee)
      const reserveOutAfter = k.div(reserveInAfter)

      const amountOut = reserveOut.sub(reserveOutAfter)
      expect(amountOut, 'amount out is less than the reserves out').to.be.lt(reserveOut)
      expect(amountOut).to.eq('62269752876055359223767967182589')

      const priceAfter = reserveInAfter.mul(BigNumber.from(2).pow(112)).div(reserveOutAfter)
      expect(priceAfter, 'price after exceeds in out ratio').to.be.gte(inOutRatio)
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
