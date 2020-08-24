import chai, { expect } from 'chai'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'
import { Contract, BigNumber } from 'ethers'

import FixedPointExtraTest from '../build/FixedPointExtraTest.json'

chai.use(solidity)

const overrides = {
  gasLimit: 9999999
}

const Q112 = BigNumber.from(2).pow(112)

describe('FixedPointExtra', () => {
  const provider = new MockProvider({
    ganacheOptions: {
      hardfork: 'istanbul',
      mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
      gasLimit: 9999999
    }
  })
  const [wallet] = provider.getWallets()

  let fixedPointExtra: Contract
  before('deploy FixedPointExtraTest', async () => {
    fixedPointExtra = await deployContract(wallet, FixedPointExtraTest, [], overrides)
  })

  describe('#muluq', () => {
    it('1 x 1 == 1', async () => {
      expect((await fixedPointExtra.muluq([Q112], [Q112]))[0]).to.eq(Q112)
    })

    it('3.5 x 2.2 == 7.7', async () => {
      expect((await fixedPointExtra.muluq([Q112.mul(35).div(10)], [Q112.mul(22).div(10)]))[0]).to.eq(
        Q112.mul(77)
          .div(10)
          .sub(1) // off by 1 * 2^-112
      )
    })

    it('short circuits for zero', async () => {
      expect((await fixedPointExtra.muluq([Q112.mul(35).div(10)], [BigNumber.from(0)]))[0]).to.eq('0')
      expect((await fixedPointExtra.muluq([BigNumber.from(0)], [Q112.mul(22).div(10)]))[0]).to.eq('0')
      expect(await fixedPointExtra.muluqGasUsed([BigNumber.from(0)], [Q112.mul(22).div(10)])).to.eq('231')
    })

    it('throws for underflow', async () => {
      await expect(fixedPointExtra.muluq([BigNumber.from(1)], [BigNumber.from(1)])).to.be.revertedWith(
        'FixedPointExtra: MULTIPLICATION_UNDERFLOW'
      )
    })

    it('throws for overflow', async () => {
      await expect(
        fixedPointExtra.muluq([Q112.mul(BigNumber.from(2).pow(56))], [Q112.mul(BigNumber.from(2).pow(56))])
      ).to.be.revertedWith('FixedPointExtra: MULTIPLICATION_OVERFLOW')
    })

    it('gas', async () => {
      expect(await fixedPointExtra.muluqGasUsed([Q112.mul(35).div(10)], [Q112.mul(22).div(10)])).to.eq('686')
    })
  })

  describe('#divuq', () => {
    it('1 / 1 == 1', async () => {
      expect((await fixedPointExtra.divuq([Q112], [Q112]))[0]).to.eq(Q112)
    })

    it('3.5 / 2.2 == ~1.5909090909', async () => {
      expect((await fixedPointExtra.divuq([Q112.mul(35).div(10)], [Q112.mul(22).div(10)]))[0]).to.eq(
        Q112.mul(35)
          .div(22)
          .sub(3) // off by 3 * 2^-112
      )
    })

    it('gas', async () => {
      expect(await fixedPointExtra.divuqGasUsed([Q112.mul(35).div(10)], [Q112.mul(22).div(10)])).to.eq('1102')
    })
  })
})
