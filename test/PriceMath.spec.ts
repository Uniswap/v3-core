import chai, { expect } from 'chai'
import { Contract, BigNumber } from 'ethers'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'

import PriceMathTest from '../build/PriceMathTest.json'
import { expandTo18Decimals } from './shared/utilities'

chai.use(solidity)

describe('PriceMath', () => {
  const provider = new MockProvider({
    ganacheOptions: {
      hardfork: 'istanbul',
      mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
      gasLimit: 9999999
    }
  })
  const [wallet] = provider.getWallets()

  let priceMath: Contract
  beforeEach(async () => {
    priceMath = await deployContract(wallet, PriceMathTest, [])
  })

  describe('#getTradeToRatio', () => {
    describe('edge cases', () => {
      it('0 all', async () => {
        await expect(priceMath.getTradeToRatio(0, 0, 0, [0])).to.be.revertedWith('PriceMath: NONZERO')
      })

      it('throws if wrong direction', async () => {
        // no amount in will move the ratio of reserve in/reserve out from 1:50 to 1:75
        await expect(
          priceMath.getTradeToRatio(expandTo18Decimals(1), expandTo18Decimals(50), 3000, [
            expandTo18Decimals(1)
              .mul(BigNumber.from(2).pow(112))
              .div(expandTo18Decimals(75))
          ])
        ).to.be.revertedWith('PriceMath: DIRECTION')
      })

      it('returns 0 if price is equal', async () => {
        expect(
          await priceMath.getTradeToRatio(expandTo18Decimals(1), expandTo18Decimals(50), 3000, [
            expandTo18Decimals(1)
              .mul(BigNumber.from(2).pow(112))
              .div(expandTo18Decimals(50))
          ])
        ).to.eq('0')
      })
    })

    describe('1:100 to 1:50 at 30bps', () => {
      it('returns 414835953198742784', async () => {
        expect(
          await priceMath.getTradeToRatio(expandTo18Decimals(1), expandTo18Decimals(100), 3000, [
            expandTo18Decimals(1)
              .mul(BigNumber.from(2).pow(112))
              .div(expandTo18Decimals(50))
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

        const targetRatio = expandTo18Decimals(1)
          .mul(BigNumber.from(2).pow(112))
          .div(expandTo18Decimals(50))
        // a difference of lte 2^56 in a uq112x112 is <= 2^-56
        expect(ratioAfter.sub(targetRatio).abs()).to.be.lte(BigNumber.from(2).pow(56))
      })
    })

    it('1:100 to 1:50 at 60bps', async () => {
      expect(
        await priceMath.getTradeToRatio(expandTo18Decimals(1), expandTo18Decimals(100), 6000, [
          expandTo18Decimals(1)
            .mul(BigNumber.from(2).pow(112))
            .div(expandTo18Decimals(50))
        ])
      ).to.eq('415460493085696914')
    })

    it('1:100 to 1:75 at 45bps', async () => {
      expect(
        await priceMath.getTradeToRatio(expandTo18Decimals(1), expandTo18Decimals(100), 4500, [
          expandTo18Decimals(1)
            .mul(BigNumber.from(2).pow(112))
            .div(expandTo18Decimals(75))
        ])
      ).to.eq('155049452346487536')
    })
  })
})
