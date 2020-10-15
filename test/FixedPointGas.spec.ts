import {MockProvider, deployContract} from 'ethereum-waffle'
import {Contract, BigNumber} from 'ethers'

import FixedPointGasTest from '../build/FixedPointGasTest.json'
import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'

const overrides = {
  gasLimit: 9999999,
}

const Q112 = BigNumber.from(2).pow(112)

describe('FixedPoint', () => {
  const provider = new MockProvider({
    ganacheOptions: {
      hardfork: 'istanbul',
      mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
      gasLimit: 9999999,
    },
  })
  const [wallet] = provider.getWallets()

  let fixedPointGas: Contract
  before('deploy FixedPointExtraTest', async () => {
    fixedPointGas = await deployContract(wallet, FixedPointGasTest, [], overrides)
  })

  describe('#muluq', () => {
    it('short circuits for zero', async () => {
      expect(await fixedPointGas.muluqGasUsed([BigNumber.from(0)], [Q112.mul(22).div(10)])).to.eq('231')
    })

    it('gas', async () => {
      await snapshotGasCost(fixedPointGas.muluqGasUsed([Q112.mul(35).div(10)], [Q112.mul(22).div(10)]))
    })
  })

  describe('#divuq', () => {
    it('gas', async () => {
      await snapshotGasCost(fixedPointGas.divuqGasUsed([Q112.mul(35).div(10)], [Q112.mul(22).div(10)]))
    })
  })
})
